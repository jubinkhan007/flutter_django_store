import re
import secrets
import string
from decimal import Decimal, ROUND_HALF_UP
from django.db import transaction
from django.utils import timezone
from datetime import timedelta

from .models import Vendor, PayoutRequest, VendorPayoutMethod
from .financial_service import FinancialService, _money


class VendorDisbursalService:
    """
    Automated Disbursal Engine for Vendor Payouts.
    Handles verification, gateway simulation for bKash, Nagad, and Bank EFT,
    automated scheduling, ledger balance holds and debit deductions.
    """

    MFS_FEE_RATE = Decimal('0.005')  # 0.5% bKash/Nagad B2C disbursal fee

    @classmethod
    def _generate_trx_id(cls, prefix: str) -> str:
        timestamp = timezone.now().strftime('%Y%m%d%H%M%S')
        random_suffix = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
        return f"{prefix}{timestamp}{random_suffix}"

    @classmethod
    def verify_payout_method(cls, payout_method: VendorPayoutMethod, notes: str = '') -> bool:
        """
        Validates account credentials and marks payout method as verified.
        bKash & Nagad: 11-digit Bangladesh phone starting with 013-019.
        Bank: Must have bank name and valid account number.
        """
        method = payout_method.method
        details = payout_method.details or {}

        if method in (VendorPayoutMethod.Method.BKASH, VendorPayoutMethod.Method.NAGAD):
            wallet_no = (
                details.get('wallet_number') or
                details.get('phone') or
                details.get('account_number') or
                ''
            ).strip().replace('-', '').replace(' ', '')

            if not re.match(r'^(?:\+?8801|01)[3-9]\d{8}$', wallet_no):
                payout_method.is_verified = False
                payout_method.verification_notes = f"Invalid {method} wallet number format."
                payout_method.save(update_fields=['is_verified', 'verification_notes', 'updated_at'])
                return False

            payout_method.is_verified = True
            payout_method.verified_at = timezone.now()
            payout_method.verification_notes = notes or f"Verified {method} personal/merchant account."
            payout_method.save(update_fields=['is_verified', 'verified_at', 'verification_notes', 'updated_at'])
            return True

        elif method == VendorPayoutMethod.Method.BANK:
            bank_name = (details.get('bank_name') or '').strip()
            account_number = (details.get('account_number') or '').strip()

            if len(bank_name) < 2 or len(account_number) < 6:
                payout_method.is_verified = False
                payout_method.verification_notes = "Bank name or account number too short."
                payout_method.save(update_fields=['is_verified', 'verification_notes', 'updated_at'])
                return False

            payout_method.is_verified = True
            payout_method.verified_at = timezone.now()
            payout_method.verification_notes = notes or f"Verified routing & BEFTN bank account for {bank_name}."
            payout_method.save(update_fields=['is_verified', 'verified_at', 'verification_notes', 'updated_at'])
            return True

        return False

    @classmethod
    def disburse_payout(cls, payout: PayoutRequest, simulated_failure: bool = False) -> dict:
        """
        Disburses a PayoutRequest to the vendor's chosen payout method (bKash, Nagad, or Bank).
        Deducts from held balance upon success via FinancialService.mark_payout_paid().
        Releases held funds back to available balance on failure via FinancialService.reject_payout().
        """
        if payout.status not in (PayoutRequest.Status.REQUESTED, PayoutRequest.Status.APPROVED, PayoutRequest.Status.PROCESSING):
            return {
                'success': False,
                'error': f"Payout #{payout.id} cannot be disbursed because status is {payout.status}."
            }

        with transaction.atomic():
            payout = PayoutRequest.objects.select_for_update().get(id=payout.id)
            vendor = payout.vendor

            # Determine channel
            channel = payout.disbursal_channel
            if not channel and payout.payout_method:
                channel = payout.payout_method.method
            if not channel:
                details_lower = payout.bank_details.lower()
                if 'bkash' in details_lower:
                    channel = 'BKASH'
                elif 'nagad' in details_lower:
                    channel = 'NAGAD'
                else:
                    channel = 'BANK'

            payout.disbursal_channel = channel

            # Check verification of payout method if attached
            if payout.payout_method and not payout.payout_method.is_verified:
                is_valid = cls.verify_payout_method(payout.payout_method)
                if not is_valid:
                    payout.status = PayoutRequest.Status.REJECTED
                    payout.failure_reason = f"Payout method verification failed: {payout.payout_method.verification_notes}"
                    payout.processed_at = timezone.now()
                    payout.save(update_fields=['status', 'failure_reason', 'processed_at'])
                    FinancialService.reject_payout(payout)
                    return {'success': False, 'error': payout.failure_reason}

            if simulated_failure:
                payout.status = PayoutRequest.Status.REJECTED
                payout.failure_reason = "Payment gateway rejected transaction (Simulated Gateway Failure)."
                payout.processed_at = timezone.now()
                payout.save(update_fields=['status', 'failure_reason', 'processed_at'])
                FinancialService.reject_payout(payout)
                return {'success': False, 'error': payout.failure_reason}

            # Calculate gateway fees
            amount = payout.amount
            if channel in ('BKASH', 'NAGAD'):
                fee = _money(amount * cls.MFS_FEE_RATE)
                trx_prefix = 'TRX-BKASH-' if channel == 'BKASH' else 'NGD-DISBURSE-'
                ref_id = cls._generate_trx_id(trx_prefix)
            else:
                fee = Decimal('0.00')  # Standard BEFTN platform fee absorbed
                ref_id = cls._generate_trx_id('BEFTN-')

            payout.status = PayoutRequest.Status.PAID
            payout.gateway_reference = ref_id
            payout.gateway_fee = fee
            payout.failure_reason = ''
            payout.processed_at = timezone.now()
            payout.save(update_fields=[
                'status', 'disbursal_channel', 'gateway_reference',
                'gateway_fee', 'failure_reason', 'processed_at'
            ])

            # Deduct from held balance into lifetime withdrawn
            FinancialService.mark_payout_paid(payout)

            # Send Notification to Vendor
            try:
                from notifications.models import Notification
                from notifications.services import NotificationService

                channel_display = dict(PayoutRequest._meta.get_field('disbursal_channel').choices).get(channel, channel)
                NotificationService.create(
                    user=vendor.user,
                    title='Payout Disbursed Successfully',
                    body=f'৳{amount:.2f} has been disbursed to your {channel_display} account. Ref: {ref_id}.',
                    event_type=Notification.Type.PAYOUT_APPROVED,
                    category=Notification.Category.TRANSACTIONAL,
                    deeplink='app://vendor/wallet',
                    data={
                        'payout_id': str(payout.id),
                        'amount': str(amount),
                        'gateway_reference': ref_id,
                        'channel': channel,
                    },
                    inbox_visible=True,
                    push_enabled=True,
                )
            except Exception:
                pass

            return {
                'success': True,
                'payout_id': payout.id,
                'amount': float(amount),
                'channel': channel,
                'gateway_reference': ref_id,
                'gateway_fee': float(fee),
            }

    @classmethod
    def process_scheduled_auto_payouts(cls, force: bool = False) -> dict:
        """
        Runs through all eligible vendors with automated payouts enabled and:
        1. Checks schedule frequency (Weekly, Biweekly, Monthly).
        2. Validates available balance against auto_payout_threshold.
        3. Identifies or verifies a payout method.
        4. Auto-deducts balance into held status.
        5. Executes gateway disbursal and records transaction reference.
        """
        now = timezone.now()
        candidates = Vendor.objects.filter(
            is_approved=True,
            is_auto_payout_enabled=True,
        )

        results = {
            'total_candidates': candidates.count(),
            'processed_count': 0,
            'total_disbursed': 0.0,
            'payouts': [],
            'skipped': [],
            'errors': [],
        }

        for vendor in candidates:
            # 1. Balance threshold check
            available = vendor.available_balance or Decimal('0.00')
            threshold = vendor.auto_payout_threshold or Decimal('1000.00')
            if available < threshold:
                results['skipped'].append({
                    'vendor_id': vendor.id,
                    'store_name': vendor.store_name,
                    'reason': f"Available balance ৳{available:.2f} below threshold ৳{threshold:.2f}",
                })
                continue

            # 2. Schedule frequency check
            if not force and vendor.last_payout_at:
                schedule = vendor.auto_payout_schedule
                days_required = 7
                if schedule == 'BIWEEKLY':
                    days_required = 14
                elif schedule == 'MONTHLY':
                    days_required = 30

                elapsed = now - vendor.last_payout_at
                if elapsed < timedelta(days=days_required):
                    results['skipped'].append({
                        'vendor_id': vendor.id,
                        'store_name': vendor.store_name,
                        'reason': f"Schedule {schedule} not due yet ({elapsed.days} of {days_required} days elapsed).",
                    })
                    continue

            # 3. Find verified payout method
            payout_method = vendor.preferred_payout_method
            if not payout_method or not payout_method.is_verified:
                payout_method = vendor.payout_methods.filter(is_verified=True).first()

            if not payout_method:
                # Try to auto-verify the first available method if valid
                candidate_method = vendor.payout_methods.first()
                if candidate_method and cls.verify_payout_method(candidate_method):
                    payout_method = candidate_method

            if not payout_method:
                results['skipped'].append({
                    'vendor_id': vendor.id,
                    'store_name': vendor.store_name,
                    'reason': "No verified payout method configured.",
                })
                continue

            # 4. Create payout request and place funds on hold
            amount = available
            try:
                with transaction.atomic():
                    # Format bank details description
                    details_str = f"{payout_method.method} ({payout_method.label or 'Auto'}): {payout_method.details}"

                    payout = PayoutRequest.objects.create(
                        vendor=vendor,
                        amount=amount,
                        payout_method=payout_method,
                        disbursal_channel=payout_method.method,
                        bank_details=details_str,
                        is_automated=True,
                        status=PayoutRequest.Status.REQUESTED,
                        admin_note="Created by Automated Scheduled Payout Disbursal Engine",
                    )

                    # Deduct from available and place on held
                    FinancialService.request_payout_hold(vendor, amount, payout)

                    # 5. Disburse via Gateway
                    disbursal_res = cls.disburse_payout(payout)
                    if disbursal_res.get('success'):
                        vendor.last_payout_at = now
                        vendor.save(update_fields=['last_payout_at'])

                        results['processed_count'] += 1
                        results['total_disbursed'] += float(amount)
                        results['payouts'].append(disbursal_res)
                    else:
                        results['errors'].append({
                            'vendor_id': vendor.id,
                            'error': disbursal_res.get('error'),
                        })
            except Exception as e:
                results['errors'].append({
                    'vendor_id': vendor.id,
                    'error': str(e),
                })

        return results
