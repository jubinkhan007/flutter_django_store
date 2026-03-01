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
        If the vendor has an outstanding debt_balance, incoming funds first clear
        the debt before being credited to available.
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

            # Debt recovery: new funds first clear any outstanding debt_balance.
            debt = _money(vendor.debt_balance or Decimal('0.00'))
            if debt > Decimal('0.00'):
                debt_cleared = min(debt, amount)
                vendor.debt_balance = _money(debt - debt_cleared)
                to_available = _money(amount - debt_cleared)
            else:
                to_available = amount

            vendor.available_balance = _money((vendor.available_balance or Decimal('0.00')) + to_available)
            vendor.balance = _money(
                (vendor.pending_balance or Decimal('0.00'))
                + (vendor.available_balance or Decimal('0.00'))
                + (vendor.held_balance or Decimal('0.00'))
                - (vendor.debt_balance or Decimal('0.00'))
            )
            vendor.save(update_fields=['pending_balance', 'available_balance', 'debt_balance', 'balance'])

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
            vendor.balance = _money(
                (vendor.pending_balance or Decimal('0.00'))
                + (vendor.available_balance or Decimal('0.00'))
                + (vendor.held_balance or Decimal('0.00'))
                - (vendor.debt_balance or Decimal('0.00'))
            )
            vendor.save(update_fields=['held_balance', 'total_withdrawn_lifetime', 'balance'])

    @classmethod
    def debit_for_refund(cls, refund_obj) -> None:
        """
        Debits the vendor's wallet when a customer refund is completed.

        The vendor's net obligation = gross refund * (1 - platform_fee_rate),
        since the platform fee portion was never paid to the vendor.

        Three scenarios based on where the vendor's money currently sits:
          A - PENDING:   Settlement not yet released → debit pending_balance.
          B - AVAILABLE: Available balance covers it → debit available_balance.
          C - DEBT:      Available insufficient → deplete available to 0,
                         record the remainder in debt_balance.

        Idempotent: uses f"refund:{refund_obj.id}" as the unique idempotency key.
        Subsequent earnings released via release_settlement() will first clear
        any outstanding debt_balance before crediting available_balance.
        """
        from returns.models import ReturnItem

        idempotency_key = f"refund:{refund_obj.id}"

        # Fast-path idempotency check before acquiring the row lock.
        if LedgerEntry.objects.filter(idempotency_key=idempotency_key).exists():
            return

        vendor_obj = refund_obj.return_request.vendor
        gross_refund = _money(refund_obj.amount)
        # The vendor only ever received (1 - fee_rate) of the sale price.
        vendor_net = _money(gross_refund * (Decimal('1') - cls.fee_config.platform_fee_rate))

        if vendor_net <= Decimal('0.00'):
            return

        with transaction.atomic():
            vendor = Vendor.objects.select_for_update().get(id=vendor_obj.id)

            # Re-check inside the lock (double-checked locking).
            if LedgerEntry.objects.filter(idempotency_key=idempotency_key).exists():
                return

            # Determine which sub-orders are involved in this return.
            sub_order_ids = list(
                ReturnItem.objects.filter(return_request=refund_obj.return_request)
                .values_list('order_item__sub_order_id', flat=True)
                .distinct()
            )

            pending_bal = _money(vendor.pending_balance or Decimal('0.00'))
            available_bal = _money(vendor.available_balance or Decimal('0.00'))
            debt_bal = _money(vendor.debt_balance or Decimal('0.00'))

            has_pending_settlement = SettlementRecord.objects.filter(
                sub_order_id__in=sub_order_ids,
                status=SettlementRecord.Status.PENDING,
            ).exists()

            update_fields = ['balance']

            if has_pending_settlement and pending_bal >= vendor_net:
                # Scenario A: funds still in pending — debit there.
                bucket = LedgerEntry.Bucket.PENDING
                vendor.pending_balance = _money(pending_bal - vendor_net)
                update_fields.append('pending_balance')

            elif available_bal >= vendor_net:
                # Scenario B: enough in available — debit there.
                bucket = LedgerEntry.Bucket.AVAILABLE
                vendor.available_balance = _money(available_bal - vendor_net)
                update_fields.append('available_balance')

            else:
                # Scenario C: not enough in available — deplete to 0, record debt.
                bucket = LedgerEntry.Bucket.AVAILABLE
                remainder = _money(vendor_net - available_bal)
                vendor.available_balance = Decimal('0.00')
                vendor.debt_balance = _money(debt_bal + remainder)
                update_fields.extend(['available_balance', 'debt_balance'])

            LedgerEntry.objects.create(
                vendor=vendor,
                entry_type=LedgerEntry.EntryType.REFUND_DEBIT,
                bucket=bucket,
                direction=LedgerEntry.Direction.DEBIT,
                status=LedgerEntry.Status.POSTED,
                amount=vendor_net,
                reference_type=LedgerEntry.ReferenceType.REFUND,
                reference_id=refund_obj.id,
                idempotency_key=idempotency_key,
                description=f"Refund debit for Refund #{refund_obj.id}",
            )

            vendor.balance = _money(
                (vendor.pending_balance or Decimal('0.00'))
                + (vendor.available_balance or Decimal('0.00'))
                + (vendor.held_balance or Decimal('0.00'))
                - (vendor.debt_balance or Decimal('0.00'))
            )
            vendor.save(update_fields=list(set(update_fields)))

