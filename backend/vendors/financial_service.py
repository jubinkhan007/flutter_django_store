from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction
from django.utils import timezone

from .models import Vendor, LedgerEntry, SettlementRecord, PayoutRequest


_CENT = Decimal('0.01')


def _money(value: Decimal) -> Decimal:
    return (value or Decimal('0.00')).quantize(_CENT, rounding=ROUND_HALF_UP)


@dataclass(frozen=True)
class FeeConfig:
    platform_fee_rate: Decimal = Decimal('0.10')  # 10%
    settlement_window_days: int = 7
    min_withdrawal_amount: Decimal = Decimal('10.00')


class FinancialService:
    """
    Ledger-first financial engine.
    LedgerEntry is the source of truth; Vendor bucket balances are cached aggregates.
    """

    fee_config = FeeConfig()

    @classmethod
    def accrue_earnings(cls, sub_order) -> SettlementRecord:
        """
        Called when a SubOrder becomes DELIVERED and the parent order is PAID.
        Creates:
          - SettlementRecord(status=PENDING)
          - LedgerEntry crediting PENDING bucket
          - Vendor.pending_balance + Vendor.total_earned_lifetime caches
        Idempotent via SettlementRecord(one-to-one with sub_order) + LedgerEntry unique constraint.
        """
        from orders.models import Order

        if sub_order.status != Order.Status.DELIVERED:
            raise ValueError("SubOrder must be DELIVERED to accrue earnings.")

        if sub_order.order.payment_status != Order.PaymentStatus.PAID:
            raise ValueError("Order must be PAID to accrue earnings.")

        with transaction.atomic():
            # Lock vendor row to prevent race conditions.
            vendor = Vendor.objects.select_for_update().get(id=sub_order.vendor_id)

            # Ensure we only accrue once per sub-order.
            record, created = SettlementRecord.objects.get_or_create(
                sub_order=sub_order,
                defaults={
                    'vendor': vendor,
                    'gross_amount': Decimal('0.00'),
                    'platform_fee': Decimal('0.00'),
                    'net_amount': Decimal('0.00'),
                    'settlement_date': SettlementRecord.compute_settlement_date(
                        sub_order.delivered_at,
                        window_days=cls.fee_config.settlement_window_days,
                    ),
                },
            )

            if not created:
                return record

            gross = Decimal('0.00')
            for item in sub_order.items.all():
                gross += (item.unit_price or Decimal('0.00')) * Decimal(item.quantity or 0)
            gross = _money(gross)
            platform_fee = _money(gross * cls.fee_config.platform_fee_rate)
            net = _money(gross - platform_fee)

            record.gross_amount = gross
            record.platform_fee = platform_fee
            record.net_amount = net
            record.save(update_fields=['gross_amount', 'platform_fee', 'net_amount'])

            idempotency_key = f"ACCRUE_SUBORDER_{sub_order.id}"

            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.SALE_CREDIT_PENDING,
                bucket=LedgerEntry.Bucket.PENDING,
                direction=LedgerEntry.Direction.CREDIT,
                status=LedgerEntry.Status.POSTED,
                amount=net,
                reference_type=LedgerEntry.ReferenceType.SUBORDER,
                reference_id=sub_order.id,
                idempotency_key=idempotency_key,
                description=f"Earnings accrued for SubOrder #{sub_order.id}",
            )

            vendor.pending_balance = _money((vendor.pending_balance or Decimal('0.00')) + net)
            vendor.total_earned_lifetime = _money((vendor.total_earned_lifetime or Decimal('0.00')) + net)
            vendor.balance = _money(vendor.pending_balance + vendor.available_balance + vendor.held_balance)
            vendor.save(
                update_fields=[
                    'pending_balance',
                    'total_earned_lifetime',
                    'balance',
                ],
            )

            return record

    @classmethod
    def release_settlement(cls, record: SettlementRecord) -> SettlementRecord:
        """
        Moves funds from pending -> available when settlement date is reached.
        Idempotent by record.status.
        """
        if record.status != SettlementRecord.Status.PENDING:
            return record

        today = timezone.now().date()
        if record.settlement_date > today:
            return record

        with transaction.atomic():
            record = SettlementRecord.objects.select_for_update().get(id=record.id)
            if record.status != SettlementRecord.Status.PENDING:
                return record

            vendor = Vendor.objects.select_for_update().get(id=record.vendor_id)
            amount = _money(record.net_amount)

            idempotency_key = f"RELEASE_SETTLEMENT_{record.id}"

            # Debit pending bucket
            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.SETTLEMENT_RELEASE,
                bucket=LedgerEntry.Bucket.PENDING,
                direction=LedgerEntry.Direction.DEBIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.SUBORDER,
                reference_id=record.sub_order_id,
                idempotency_key=idempotency_key,
                description=f"Settlement release for SubOrder #{record.sub_order_id}",
            )

            # Credit available bucket
            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.SETTLEMENT_RELEASE,
                bucket=LedgerEntry.Bucket.AVAILABLE,
                direction=LedgerEntry.Direction.CREDIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.SUBORDER,
                reference_id=record.sub_order_id,
                idempotency_key=idempotency_key,
                description=f"Settlement release for SubOrder #{record.sub_order_id}",
            )

            vendor.pending_balance = _money((vendor.pending_balance or Decimal('0.00')) - amount)
            vendor.available_balance = _money((vendor.available_balance or Decimal('0.00')) + amount)
            vendor.balance = _money(vendor.pending_balance + vendor.available_balance + vendor.held_balance)
            vendor.save(update_fields=['pending_balance', 'available_balance', 'balance'])

            record.status = SettlementRecord.Status.RELEASED
            record.released_at = timezone.now()
            record.save(update_fields=['status', 'released_at'])
            return record

    @classmethod
    def request_payout_hold(cls, vendor: Vendor, amount: Decimal, payout: PayoutRequest) -> None:
        amount = _money(amount)
        if amount <= 0:
            raise ValueError("Payout amount must be greater than zero.")
        if amount < cls.fee_config.min_withdrawal_amount:
            raise ValueError(f"Minimum withdrawal is {cls.fee_config.min_withdrawal_amount}.")

        with transaction.atomic():
            vendor = Vendor.objects.select_for_update().get(id=vendor.id)
            if vendor.available_balance < amount:
                raise ValueError("Insufficient available balance for this payout.")

            idempotency_key = f"PAYOUT_REQUEST_{payout.id}"

            # Debit available
            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.PAYOUT_REQUEST_HOLD,
                bucket=LedgerEntry.Bucket.AVAILABLE,
                direction=LedgerEntry.Direction.DEBIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.PAYOUT,
                reference_id=payout.id,
                idempotency_key=idempotency_key,
                description=f"Payout request hold #{payout.id}",
            )
            # Credit held
            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.PAYOUT_REQUEST_HOLD,
                bucket=LedgerEntry.Bucket.HELD,
                direction=LedgerEntry.Direction.CREDIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.PAYOUT,
                reference_id=payout.id,
                idempotency_key=idempotency_key,
                description=f"Payout request hold #{payout.id}",
            )

            vendor.available_balance = _money(vendor.available_balance - amount)
            vendor.held_balance = _money(vendor.held_balance + amount)
            vendor.balance = _money(vendor.pending_balance + vendor.available_balance + vendor.held_balance)
            vendor.save(update_fields=['available_balance', 'held_balance', 'balance'])

    @classmethod
    def reject_payout(cls, payout: PayoutRequest) -> None:
        if payout.status != PayoutRequest.Status.REJECTED:
            raise ValueError("Payout must be REJECTED before releasing held funds.")

        with transaction.atomic():
            payout = PayoutRequest.objects.select_for_update().get(id=payout.id)
            vendor = Vendor.objects.select_for_update().get(id=payout.vendor_id)
            amount = _money(payout.amount)

            idempotency_key = f"PAYOUT_REJECT_{payout.id}"

            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.PAYOUT_REJECTED_RELEASE,
                bucket=LedgerEntry.Bucket.HELD,
                direction=LedgerEntry.Direction.DEBIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.PAYOUT,
                reference_id=payout.id,
                idempotency_key=idempotency_key,
                description=f"Payout rejected release #{payout.id}",
            )
            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.PAYOUT_REJECTED_RELEASE,
                bucket=LedgerEntry.Bucket.AVAILABLE,
                direction=LedgerEntry.Direction.CREDIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.PAYOUT,
                reference_id=payout.id,
                idempotency_key=idempotency_key,
                description=f"Payout rejected release #{payout.id}",
            )

            vendor.held_balance = _money(vendor.held_balance - amount)
            vendor.available_balance = _money(vendor.available_balance + amount)
            vendor.balance = _money(vendor.pending_balance + vendor.available_balance + vendor.held_balance)
            vendor.save(update_fields=['held_balance', 'available_balance', 'balance'])

    @classmethod
    def mark_payout_paid(cls, payout: PayoutRequest) -> None:
        if payout.status != PayoutRequest.Status.PAID:
            raise ValueError("Payout must be PAID to post the payout debit.")

        with transaction.atomic():
            payout = PayoutRequest.objects.select_for_update().get(id=payout.id)
            vendor = Vendor.objects.select_for_update().get(id=payout.vendor_id)
            amount = _money(payout.amount)

            idempotency_key = f"PAYOUT_PAID_{payout.id}"

            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.PAYOUT_PAID,
                bucket=LedgerEntry.Bucket.HELD,
                direction=LedgerEntry.Direction.DEBIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.PAYOUT,
                reference_id=payout.id,
                idempotency_key=idempotency_key,
                description=f"Payout paid #{payout.id}",
            )

            vendor.held_balance = _money(vendor.held_balance - amount)
            vendor.total_withdrawn_lifetime = _money((vendor.total_withdrawn_lifetime or Decimal('0.00')) + amount)
            vendor.balance = _money(vendor.pending_balance + vendor.available_balance + vendor.held_balance)
            vendor.save(update_fields=['held_balance', 'total_withdrawn_lifetime', 'balance'])

