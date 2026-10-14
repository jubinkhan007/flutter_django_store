from decimal import Decimal
import uuid
from django.contrib.admin.sites import site
from django.contrib.messages.storage.fallback import FallbackStorage
from django.test import RequestFactory, TestCase
from django.utils import timezone

from ads.admin import AdCampaignAdmin, AdImpressionAdmin, AdClickAdmin
from ads.models import AdCampaign, AdImpression, AdClick
from orders.admin import OrderAdmin
from orders.models import Order
from products.models import Product
from returns.admin import ReturnRequestAdmin
from returns.models import ReturnRequest
from reviews.admin import ReviewAdmin
from reviews.models import Review
from users.admin import UserAdmin, CustomerWalletTransactionAdmin
from users.models import CustomerWalletTransaction, User
from vendors.models import Vendor
from config.settings import _unfold_dashboard_callback


class AdminConsoleTest(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.superuser = User.objects.create_superuser(
            email="admin@example.com",
            username="admin",
            password="adminpassword123",
        )
        self.customer = User.objects.create_user(
            email="customer@example.com",
            username="customer",
            password="customerpassword123",
            wallet_balance=Decimal("250.00"),
        )
        self.vendor_user = User.objects.create_user(
            email="vendor@example.com",
            username="vendor",
            password="vendorpassword123",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="TechMart",
            is_approved=True,
            is_live=True,
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            name="Wireless Mouse",
            price=Decimal("50.00"),
            stock_quantity=100,
            is_available=True,
        )
        self.campaign = AdCampaign.objects.create(
            vendor=self.vendor,
            product=self.product,
            budget_total=Decimal("1000.00"),
            budget_spent=Decimal("250.00"),
            cost_per_click=Decimal("5.00"),
            status=AdCampaign.Status.ACTIVE,
        )
        self.order = Order.objects.create(
            customer=self.customer,
            subtotal_amount=Decimal("500.00"),
            discount_amount=Decimal("50.00"),
            total_amount=Decimal("450.00"),
            wallet_amount_applied=Decimal("100.00"),
            status=Order.Status.PENDING,
        )

    def _create_request(self):
        from django.contrib.sessions.middleware import SessionMiddleware
        from django.contrib.messages.middleware import MessageMiddleware

        request = self.factory.get('/')
        request.user = self.superuser
        SessionMiddleware(lambda req: None).process_request(request)
        request.session.save()
        MessageMiddleware(lambda req: None).process_request(request)
        return request

    def test_admin_site_registrations(self):
        """Ensure all required models are registered on the admin site."""
        self.assertIn(AdCampaign, site._registry)
        self.assertIn(AdImpression, site._registry)
        self.assertIn(AdClick, site._registry)
        self.assertIn(User, site._registry)
        self.assertIn(CustomerWalletTransaction, site._registry)
        self.assertIn(Order, site._registry)
        self.assertIn(Review, site._registry)
        self.assertIn(ReturnRequest, site._registry)

    def test_ad_campaign_admin_helpers_and_actions(self):
        """Test AdCampaignAdmin displays and actions."""
        admin = AdCampaignAdmin(AdCampaign, site)
        
        # Test displays
        self.assertEqual(admin.show_status(self.campaign), AdCampaign.Status.ACTIVE)
        self.assertEqual(admin.budget_spent_display(self.campaign), "৳250.00")
        self.assertEqual(admin.show_budget_progress(self.campaign), "25.0%")
        self.assertEqual(admin.show_impressions_count(self.campaign), 0)
        self.assertEqual(admin.show_clicks_count(self.campaign), 0)
        self.assertEqual(admin.show_ctr(self.campaign), "0.00%")

        # Create impression and click
        session_id = uuid.uuid4()
        AdImpression.objects.create(
            campaign=self.campaign,
            session_id=session_id,
            source="SEARCH",
            minute_bucket=timezone.now(),
        )
        AdClick.objects.create(
            campaign=self.campaign,
            session_id=session_id,
            click_id=uuid.uuid4(),
        )
        self.assertEqual(admin.show_impressions_count(self.campaign), 1)
        self.assertEqual(admin.show_clicks_count(self.campaign), 1)
        self.assertEqual(admin.show_ctr(self.campaign), "100.00%")

        # Test pause action
        request = self._create_request()
        admin.pause_campaigns(request, AdCampaign.objects.filter(pk=self.campaign.pk))
        self.campaign.refresh_from_db()
        self.assertEqual(self.campaign.status, AdCampaign.Status.PAUSED)

        # Test resume action
        admin.resume_campaigns(request, AdCampaign.objects.filter(pk=self.campaign.pk))
        self.campaign.refresh_from_db()
        self.assertEqual(self.campaign.status, AdCampaign.Status.ACTIVE)

        # Test mark exhausted action
        admin.mark_as_exhausted(request, AdCampaign.objects.filter(pk=self.campaign.pk))
        self.campaign.refresh_from_db()
        self.assertEqual(self.campaign.status, AdCampaign.Status.EXHAUSTED)

    def test_ad_impression_and_click_admin_permissions(self):
        """Impressions and clicks should be read-only in the admin."""
        request = self._create_request()

        imp_admin = AdImpressionAdmin(AdImpression, site)
        self.assertFalse(imp_admin.has_add_permission(request))
        self.assertFalse(imp_admin.has_change_permission(request))

        click_admin = AdClickAdmin(AdClick, site)
        self.assertFalse(click_admin.has_add_permission(request))
        self.assertFalse(click_admin.has_change_permission(request))

    def test_user_admin_wallet_credit_actions(self):
        """Test UserAdmin wallet credit action adds balance and creates transaction."""
        admin = UserAdmin(User, site)
        request = self._create_request()

        initial_balance = self.customer.wallet_balance
        admin.credit_wallet_100(request, User.objects.filter(pk=self.customer.pk))
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.wallet_balance, initial_balance + Decimal('100.00'))

        txn = CustomerWalletTransaction.objects.filter(user=self.customer).latest('created_at')
        self.assertEqual(txn.amount, Decimal('100.00'))
        self.assertEqual(txn.transaction_type, CustomerWalletTransaction.TransactionType.CREDIT)

    def test_order_admin_invoice_link(self):
        """Test OrderAdmin invoice link and financial displays."""
        admin = OrderAdmin(Order, site)
        self.assertEqual(admin.total_amount_display(self.order), "৳450.00")
        self.assertEqual(admin.wallet_applied_display(self.order), "-৳100.00")
        self.assertEqual(admin.payable_amount_display(self.order), "৳350.00")

        link_html = admin.invoice_link(self.order)
        self.assertIn(f"/api/orders/{self.order.pk}/invoice/pdf/", link_html)
        self.assertIn("PDF", link_html)

    def test_review_admin_helpers_and_actions(self):
        """Test ReviewAdmin ratings, badges, and verification action."""
        review = Review.objects.create(
            customer=self.customer,
            product=self.product,
            rating=5,
            comment="Excellent mouse, very responsive!",
            is_verified_purchase=False,
        )
        admin = ReviewAdmin(Review, site)
        self.assertIn("★★★★★", admin.show_rating_stars(review))
        self.assertFalse(admin.show_verified(review))

        request = self._create_request()
        admin.mark_as_verified(request, Review.objects.filter(pk=review.pk))
        review.refresh_from_db()
        self.assertTrue(review.is_verified_purchase)
        self.assertTrue(admin.show_verified(review))

    def test_return_request_admin_actions(self):
        """Test ReturnRequestAdmin status changes and actions."""
        rma = ReturnRequest.objects.create(
            order=self.order,
            customer=self.customer,
            vendor=self.vendor,
            request_type=ReturnRequest.RequestType.RETURN,
            status=ReturnRequest.Status.SUBMITTED,
            reason=ReturnRequest.Reason.DEFECTIVE,
        )
        admin = ReturnRequestAdmin(ReturnRequest, site)
        request = self._create_request()

        admin.approve_requests(request, ReturnRequest.objects.filter(pk=rma.pk))
        rma.refresh_from_db()
        self.assertEqual(rma.status, ReturnRequest.Status.VENDOR_APPROVED)

    def test_unfold_dashboard_callback(self):
        """Test _unfold_dashboard_callback enriches context with ads, wallets, and orders."""
        request = self._create_request()
        context = {}
        enriched = _unfold_dashboard_callback(request, context)

        self.assertIn('dashboard_metrics', enriched)
        metrics = enriched['dashboard_metrics']
        self.assertIn('sales_today_display', metrics)
        self.assertIn('ad_revenue_display', metrics)
        self.assertIn('wallet_liability_display', metrics)
        self.assertIn('active_campaigns', metrics)
        self.assertIn('chart_sales_7d_json', enriched)
        self.assertIn('chart_order_status_json', enriched)
