from decimal import Decimal
from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from orders.models import Order, SubOrder, OrderItem, Address
from vendors.models import Vendor, SettlementRecord
from returns.models import ReturnRequest
from loyalty.models import LoyaltyAccount
from analytics.services import MarketplaceAnalyticsService
from config.settings import _unfold_dashboard_callback

User = get_user_model()


class MarketplaceAnalyticsDashboardTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Admin user
        self.admin_user = User.objects.create_superuser(
            email='admin@marketplace.com',
            username='admin_ops',
            password='Password123!',
        )

        # Regular customer
        self.customer = User.objects.create_user(
            email='customer@example.com',
            username='customer_one',
            password='Password123!',
            type=User.Types.CUSTOMER,
            wallet_balance=Decimal('500.00'),
        )

        # Vendor user 1 & Profile
        self.vendor_user_1 = User.objects.create_user(
            email='vendor1@example.com',
            username='vendor_one',
            password='Password123!',
            type=User.Types.VENDOR,
        )
        self.vendor_1 = Vendor.objects.create(
            user=self.vendor_user_1,
            store_name='ElectroTech Hub',
            is_approved=True,
            is_live=True,
            avg_rating=Decimal('4.8'),
        )

        # Vendor user 2 & Profile
        self.vendor_user_2 = User.objects.create_user(
            email='vendor2@example.com',
            username='vendor_two',
            password='Password123!',
            type=User.Types.VENDOR,
        )
        self.vendor_2 = Vendor.objects.create(
            user=self.vendor_user_2,
            store_name='Dhaka Fashion House',
            is_approved=True,
            is_live=True,
            avg_rating=Decimal('4.5'),
        )

        # Loyalty Account for Customer: 1500 points = 150.00 BDT liability
        self.loyalty_account = LoyaltyAccount.objects.create(
            user=self.customer,
            points_balance=1500,
            lifetime_points_earned=2000,
            lifetime_points_redeemed=500,
            tier=LoyaltyAccount.Tier.SILVER,
        )

    def test_empty_marketplace_kpis(self):
        """Service handles zero-data scenarios gracefully without exceptions or division-by-zero."""
        # Temporarily clear loyalty accounts and wallet balance
        LoyaltyAccount.objects.all().delete()
        User.objects.filter(id=self.customer.id).update(wallet_balance=Decimal('0.00'))

        kpis = MarketplaceAnalyticsService.get_marketplace_kpis(days=30)

        self.assertIn('gmv', kpis)
        self.assertEqual(kpis['gmv']['period_total'], 0.0)
        self.assertEqual(kpis['gmv']['orders_count'], 0)
        self.assertEqual(kpis['gmv']['growth_pct'], 0.0)

        self.assertIn('commission', kpis)
        self.assertEqual(kpis['commission']['period_total'], 0.0)

        self.assertIn('top_vendors', kpis)
        self.assertEqual(kpis['top_vendors'], [])

        self.assertIn('refunds', kpis)
        self.assertEqual(kpis['refunds']['refund_rate_pct'], 0.0)
        self.assertEqual(kpis['refunds']['rma_count'], 0)

        self.assertIn('loyalty_liabilities', kpis)
        self.assertEqual(kpis['loyalty_liabilities']['total_points_balance'], 0)
        self.assertEqual(kpis['loyalty_liabilities']['points_liability_bdt'], 0.0)
        self.assertEqual(kpis['loyalty_liabilities']['wallet_liability_bdt'], 0.0)

        self.assertIn('charts', kpis)
        self.assertIn('gmv_trends', kpis['charts'])
        self.assertIn('top_vendors', kpis['charts'])
        self.assertIn('order_status', kpis['charts'])
        self.assertIn('return_reasons', kpis['charts'])

    def test_marketplace_gmv_and_commission_calculations(self):
        """GMV, commission, and settlements are accurately aggregated."""
        now = timezone.now()

        # Order 1: Paid, ৳3,000.00
        order_1 = Order.objects.create(
            customer=self.customer,
            total_amount=Decimal('3000.00'),
            status=Order.Status.PAID,
            created_at=now,
        )
        suborder_1 = SubOrder.objects.create(
            order=order_1,
            vendor=self.vendor_1,
            status=Order.Status.PAID,
            created_at=now,
        )
        # Settlement: Platform fee ৳300.00 (10%), gross ৳3000.00
        SettlementRecord.objects.create(
            sub_order=suborder_1,
            vendor=self.vendor_1,
            gross_amount=Decimal('3000.00'),
            platform_fee=Decimal('300.00'),
            net_amount=Decimal('2700.00'),
            status=SettlementRecord.Status.RELEASED,
            settlement_date=now.date(),
            created_at=now,
        )

        # Order 2: Delivered, ৳1,500.00
        order_2 = Order.objects.create(
            customer=self.customer,
            total_amount=Decimal('1500.00'),
            status=Order.Status.DELIVERED,
            created_at=now,
        )
        suborder_2 = SubOrder.objects.create(
            order=order_2,
            vendor=self.vendor_2,
            status=Order.Status.DELIVERED,
            created_at=now,
        )
        # Settlement: Platform fee ৳150.00, gross ৳1500.00
        SettlementRecord.objects.create(
            sub_order=suborder_2,
            vendor=self.vendor_2,
            gross_amount=Decimal('1500.00'),
            platform_fee=Decimal('150.00'),
            net_amount=Decimal('1350.00'),
            status=SettlementRecord.Status.PENDING,
            settlement_date=now.date(),
            created_at=now,
        )

        # Order 3: Canceled, ৳500.00 (should NOT count towards GMV)
        Order.objects.create(
            customer=self.customer,
            total_amount=Decimal('500.00'),
            status=Order.Status.CANCELED,
            created_at=now,
        )

        kpis = MarketplaceAnalyticsService.get_marketplace_kpis(days=30)

        # GMV = 3000 + 1500 = 4500
        self.assertEqual(kpis['gmv']['period_total'], 4500.0)
        self.assertEqual(kpis['gmv']['orders_count'], 2)
        self.assertEqual(kpis['gmv']['aov'], 2250.0)

        # Commission = 300 + 150 = 450
        self.assertEqual(kpis['commission']['period_total'], 450.0)
        self.assertEqual(kpis['commission']['released'], 300.0)
        self.assertEqual(kpis['commission']['pending'], 150.0)

        # Top vendors ranked by GMV
        top = kpis['top_vendors']
        self.assertEqual(len(top), 2)
        self.assertEqual(top[0]['store_name'], 'ElectroTech Hub')
        self.assertEqual(top[0]['gmv'], 3000.0)
        self.assertEqual(top[0]['commission'], 300.0)

        self.assertEqual(top[1]['store_name'], 'Dhaka Fashion House')
        self.assertEqual(top[1]['gmv'], 1500.0)
        self.assertEqual(top[1]['commission'], 150.0)

    def test_refund_rates_and_rma_metrics(self):
        """Refund rates and return reasons are correctly categorized."""
        now = timezone.now()

        # Order 1: Completed
        order_1 = Order.objects.create(
            customer=self.customer,
            total_amount=Decimal('2000.00'),
            status=Order.Status.DELIVERED,
            created_at=now,
        )

        # Order 2: Refunded
        order_2 = Order.objects.create(
            customer=self.customer,
            total_amount=Decimal('1000.00'),
            status=Order.Status.DELIVERED,
            payment_status=Order.PaymentStatus.REFUNDED,
            created_at=now,
        )

        # Create RMA ReturnRequest
        ReturnRequest.objects.create(
            order=order_2,
            customer=self.customer,
            vendor=self.vendor_1,
            request_type=ReturnRequest.RequestType.RETURN,
            status=ReturnRequest.Status.REFUNDED,
            reason=ReturnRequest.Reason.DEFECTIVE,
            reason_details='Device would not power on',
        )

        kpis = MarketplaceAnalyticsService.get_marketplace_kpis(days=30)
        refunds = kpis['refunds']

        self.assertEqual(refunds['total_orders'], 2)
        self.assertEqual(refunds['refunded_orders_count'], 1)
        self.assertEqual(refunds['refund_rate_pct'], 50.0)
        self.assertEqual(refunds['rma_count'], 1)
        self.assertEqual(refunds['rma_refunded_count'], 1)
        self.assertEqual(refunds['refunded_amount'], 1000.0)
        self.assertIn('DEFECTIVE', refunds['reasons'])
        self.assertEqual(refunds['reasons']['DEFECTIVE'], 1)

    def test_loyalty_points_and_wallet_liabilities(self):
        """Loyalty points liability translates 10 points = 1.00 BDT, combined with customer wallet balance."""
        kpis = MarketplaceAnalyticsService.get_marketplace_kpis(days=30)
        liabilities = kpis['loyalty_liabilities']

        # 1500 points at 10 pts per BDT = ৳150.00 liability
        self.assertEqual(liabilities['total_points_balance'], 1500)
        self.assertEqual(liabilities['points_liability_bdt'], 150.0)
        self.assertEqual(liabilities['lifetime_earned'], 2000)
        self.assertEqual(liabilities['lifetime_redeemed'], 500)
        self.assertEqual(liabilities['lifetime_discount_bdt'], 50.0)

        # Customer wallet balance = ৳500.00
        self.assertEqual(liabilities['wallet_liability_bdt'], 500.0)

        # Total combined liability = 150 + 500 = 650.00
        self.assertEqual(liabilities['total_liability_bdt'], 650.0)

    def test_api_marketplace_summary_access_control(self):
        """Unauthorized requests are forbidden; Admin receives full 200 OK JSON report."""
        url = '/api/analytics/marketplace/summary/'

        # 1. Anonymous request
        res_anon = self.client.get(url)
        self.assertIn(res_anon.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

        # 2. Customer user request
        self.client.force_authenticate(user=self.customer)
        res_customer = self.client.get(url)
        self.assertEqual(res_customer.status_code, status.HTTP_403_FORBIDDEN)

        # 3. Admin user request
        self.client.force_authenticate(user=self.admin_user)
        res_admin = self.client.get(url + '?days=14')
        self.assertEqual(res_admin.status_code, status.HTTP_200_OK)

        data = res_admin.json()
        self.assertEqual(data['days'], 14)
        self.assertIn('gmv', data)
        self.assertIn('commission', data)
        self.assertIn('top_vendors', data)
        self.assertIn('refunds', data)
        self.assertIn('loyalty_liabilities', data)
        self.assertIn('charts', data)

    def test_unfold_dashboard_callback_injects_analytics_context(self):
        """_unfold_dashboard_callback successfully injects metrics and JSON chart objects."""
        from django.test import RequestFactory
        factory = RequestFactory()
        request = factory.get('/admin/')
        request.user = self.admin_user

        context = {}
        result_context = _unfold_dashboard_callback(request, context)

        self.assertIn('dashboard_metrics', result_context)
        self.assertIn('analytics_kpis', result_context)
        self.assertIn('chart_gmv_trends_json', result_context)
        self.assertIn('chart_top_vendors_json', result_context)
        self.assertIn('chart_order_status_json', result_context)
        self.assertIn('chart_return_reasons_json', result_context)

        metrics = result_context['dashboard_metrics']
        self.assertIn('gmv_30d_display', metrics)
        self.assertIn('commission_30d_display', metrics)
        self.assertIn('refund_rate_pct', metrics)
        self.assertIn('loyalty_liability_display', metrics)
        self.assertIn('total_liability_display', metrics)
