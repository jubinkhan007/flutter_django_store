from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from vendors.disbursal_service import VendorDisbursalService
from vendors.financial_service import FinancialService, _money
from vendors.models import Vendor, VendorPayoutMethod, PayoutRequest, LedgerEntry

User = get_user_model()


class AutomatedVendorPayoutsTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='vendor_payout_user',
            email='payout_vendor@example.com',
            password='Password123!',
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.user,
            store_name='Electro Bangladesh',
            is_approved=True,
            available_balance=Decimal('2500.00'),
            held_balance=Decimal('0.00'),
            pending_balance=Decimal('500.00'),
            total_earned_lifetime=Decimal('3000.00'),
            total_withdrawn_lifetime=Decimal('0.00'),
            is_auto_payout_enabled=True,
            auto_payout_schedule='WEEKLY',
            auto_payout_threshold=Decimal('1000.00'),
        )
        self.vendor.recache_balance()

        self.bkash_method = VendorPayoutMethod.objects.create(
            vendor=self.vendor,
            method=VendorPayoutMethod.Method.BKASH,
            label='bKash Merchant',
            details={'wallet_number': '01712345678'},
            is_verified=False,
        )

        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_verify_payout_methods(self):
        # Valid bKash
        ok = VendorDisbursalService.verify_payout_method(self.bkash_method)
        self.assertTrue(ok)
        self.bkash_method.refresh_from_db()
        self.assertTrue(self.bkash_method.is_verified)
        self.assertIsNotNone(self.bkash_method.verified_at)

        # Invalid bKash wallet number
        invalid_method = VendorPayoutMethod.objects.create(
            vendor=self.vendor,
            method=VendorPayoutMethod.Method.BKASH,
            label='Invalid bKash',
            details={'wallet_number': '12345'},
        )
        ok_invalid = VendorDisbursalService.verify_payout_method(invalid_method)
        self.assertFalse(ok_invalid)
        invalid_method.refresh_from_db()
        self.assertFalse(invalid_method.is_verified)

        # Valid Bank method
        bank_method = VendorPayoutMethod.objects.create(
            vendor=self.vendor,
            method=VendorPayoutMethod.Method.BANK,
            label='Main Bank Acct',
            details={'bank_name': 'BRAC Bank Ltd', 'account_number': '1501203498001'},
        )
        ok_bank = VendorDisbursalService.verify_payout_method(bank_method)
        self.assertTrue(ok_bank)
        bank_method.refresh_from_db()
        self.assertTrue(bank_method.is_verified)

    def test_disburse_payout_success(self):
        # Attach verified payout method
        self.bkash_method.is_verified = True
        self.bkash_method.save()

        payout = PayoutRequest.objects.create(
            vendor=self.vendor,
            amount=Decimal('1500.00'),
            payout_method=self.bkash_method,
            disbursal_channel='BKASH',
            bank_details='bKash: 01712345678',
            status=PayoutRequest.Status.REQUESTED,
        )
        # Put funds on hold
        FinancialService.request_payout_hold(self.vendor, Decimal('1500.00'), payout)
        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('1000.00'))
        self.assertEqual(self.vendor.held_balance, Decimal('1500.00'))

        # Execute disbursal
        res = VendorDisbursalService.disburse_payout(payout)
        self.assertTrue(res['success'])
        self.assertTrue(res['gateway_reference'].startswith('TRX-BKASH-'))

        payout.refresh_from_db()
        self.assertEqual(payout.status, PayoutRequest.Status.PAID)
        self.assertEqual(payout.disbursal_channel, 'BKASH')
        self.assertTrue(len(payout.gateway_reference) > 10)

        # Balances should reflect completed debit
        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('1000.00'))
        self.assertEqual(self.vendor.held_balance, Decimal('0.00'))
        self.assertEqual(self.vendor.total_withdrawn_lifetime, Decimal('1500.00'))

    def test_disburse_payout_failure_recovery(self):
        payout = PayoutRequest.objects.create(
            vendor=self.vendor,
            amount=Decimal('800.00'),
            bank_details='Invalid Details',
            status=PayoutRequest.Status.REQUESTED,
        )
        FinancialService.request_payout_hold(self.vendor, Decimal('800.00'), payout)
        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('1700.00'))
        self.assertEqual(self.vendor.held_balance, Decimal('800.00'))

        # Simulate gateway failure
        res = VendorDisbursalService.disburse_payout(payout, simulated_failure=True)
        self.assertFalse(res['success'])

        payout.refresh_from_db()
        self.assertEqual(payout.status, PayoutRequest.Status.REJECTED)
        self.assertIn('Simulated Gateway Failure', payout.failure_reason)

        # Held funds must be refunded back to available_balance
        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('2500.00'))
        self.assertEqual(self.vendor.held_balance, Decimal('0.00'))

    def test_process_scheduled_auto_payouts(self):
        self.bkash_method.is_verified = True
        self.bkash_method.save()
        self.vendor.preferred_payout_method = self.bkash_method
        self.vendor.save()

        # Run scheduled auto payouts
        res = VendorDisbursalService.process_scheduled_auto_payouts(force=True)
        self.assertEqual(res['processed_count'], 1)
        self.assertEqual(res['total_disbursed'], 2500.0)

        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('0.00'))
        self.assertEqual(self.vendor.held_balance, Decimal('0.00'))
        self.assertEqual(self.vendor.total_withdrawn_lifetime, Decimal('2500.00'))
        self.assertIsNotNone(self.vendor.last_payout_at)

        # An automated PayoutRequest should exist
        payout = PayoutRequest.objects.filter(vendor=self.vendor, is_automated=True).first()
        self.assertNotNull = self.assertIsNotNone(payout)
        self.assertEqual(payout.status, PayoutRequest.Status.PAID)
        self.assertEqual(payout.amount, Decimal('2500.00'))
        self.assertTrue(payout.gateway_reference.startswith('TRX-BKASH-'))

    def test_api_verify_payout_method(self):
        url = reverse('vendor-payout-method-verify', kwargs={'pk': self.bkash_method.id})
        response = self.client.post(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'verified')

        self.bkash_method.refresh_from_db()
        self.assertTrue(self.bkash_method.is_verified)

    def test_api_payout_settings(self):
        url = reverse('vendor-payout-settings')
        # GET settings
        get_res = self.client.get(url)
        self.assertEqual(get_res.status_code, status.HTTP_200_OK)
        self.assertTrue(get_res.data['is_auto_payout_enabled'])
        self.assertEqual(get_res.data['auto_payout_schedule'], 'WEEKLY')

        # UPDATE settings
        post_res = self.client.post(url, {
            'is_auto_payout_enabled': False,
            'auto_payout_schedule': 'MONTHLY',
            'auto_payout_threshold': '2000.00',
        })
        self.assertEqual(post_res.status_code, status.HTTP_200_OK)
        self.vendor.refresh_from_db()
        self.assertFalse(self.vendor.is_auto_payout_enabled)
        self.assertEqual(self.vendor.auto_payout_schedule, 'MONTHLY')
        self.assertEqual(self.vendor.auto_payout_threshold, Decimal('2000.00'))

    def test_api_create_payout_with_auto_disburse(self):
        self.bkash_method.is_verified = True
        self.bkash_method.save()

        url = reverse('vendor-payouts')
        payload = {
            'amount': '500.00',
            'payout_method': self.bkash_method.id,
            'auto_disburse': True,
        }
        res = self.client.post(url, payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['status'], PayoutRequest.Status.PAID)
        self.assertTrue(res.data['gateway_reference'].startswith('TRX-BKASH-'))
        self.assertEqual(res.data['disbursal_channel'], 'BKASH')

        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('2000.00'))
        self.assertEqual(self.vendor.total_withdrawn_lifetime, Decimal('500.00'))
