from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from products.models import Product, Category
from vendors.models import Vendor, SettlementRecord
from users.models import Address
from coupons.models import Coupon
from loyalty.models import LoyaltyAccount
from orders.models import Order, SubOrder
from orders.split_checkout_service import MultiVendorSplitCheckoutService

User = get_user_model()


class MultiVendorSplitCheckoutTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Customer
        self.customer = User.objects.create_user(
            email='shopper@example.com',
            username='shopper_bd',
            password='Password123!',
            type=User.Types.CUSTOMER,
            wallet_balance=Decimal('200.00'),
        )
        self.address = Address.objects.create(
            user=self.customer,
            label='Home',
            phone_number='01711223344',
            address_line='House 12, Road 4, Dhanmondi',
            city='Dhaka',
        )

        # Vendor 1
        self.vendor_user_1 = User.objects.create_user(
            email='gadgetvendor@example.com',
            username='gadget_vendor',
            password='Password123!',
            type=User.Types.VENDOR,
        )
        self.vendor_1 = Vendor.objects.create(
            user=self.vendor_user_1,
            store_name='Gadget Bazaar',
            is_approved=True,
            is_live=True,
        )

        # Vendor 2
        self.vendor_user_2 = User.objects.create_user(
            email='apparelvendor@example.com',
            username='apparel_vendor',
            password='Password123!',
            type=User.Types.VENDOR,
        )
        self.vendor_2 = Vendor.objects.create(
            user=self.vendor_user_2,
            store_name='Dhaka Threads',
            is_approved=True,
            is_live=True,
        )

        # Products
        self.category = Category.objects.create(name='Electronics')
        self.product_v1 = Product.objects.create(
            vendor=self.vendor_1,
            category=self.category,
            name='Bluetooth Speaker',
            price=Decimal('2000.00'),
            stock_quantity=10,
            is_available=True,
        )

        self.product_v2 = Product.objects.create(
            vendor=self.vendor_2,
            category=self.category,
            name='Cotton Polo T-Shirt',
            price=Decimal('1000.00'),
            stock_quantity=15,
            is_available=True,
        )

        # Global 10% coupon
        self.global_coupon = Coupon.objects.create(
            code='SAVE10',
            discount_type=Coupon.DiscountType.PERCENT,
            discount_value=Decimal('10.00'),
            is_active=True,
            scope=Coupon.Scope.GLOBAL,
        )

        # Vendor 1 scoped flat ৳200 coupon
        self.vendor1_coupon = Coupon.objects.create(
            code='GADGET200',
            discount_type=Coupon.DiscountType.FIXED,
            discount_value=Decimal('200.00'),
            is_active=True,
            scope=Coupon.Scope.VENDOR,
            vendor=self.vendor_1,
        )

        # Loyalty Account
        self.loyalty_acc = LoyaltyAccount.objects.create(
            user=self.customer,
            points_balance=1000,  # 1000 pts = ৳100.00
            lifetime_points_earned=1000,
            tier=LoyaltyAccount.Tier.BRONZE,
        )

    def test_multi_vendor_quote_with_partial_coupon_allocation(self):
        """Global coupon is proportionally split across Vendor 1 and Vendor 2 packages."""
        items = [
            {'product': self.product_v1.id, 'quantity': 1},  # ৳2,000 (Vendor 1)
            {'product': self.product_v2.id, 'quantity': 1},  # ৳1,000 (Vendor 2)
        ]

        quote = MultiVendorSplitCheckoutService.compute_multi_vendor_quote(
            items_data=items,
            coupon_code='SAVE10',  # 10% off = ৳300.00
            user=self.customer,
        )

        self.assertEqual(quote['subtotal'], '3000.00')
        self.assertEqual(quote['discount'], '300.00')
        self.assertEqual(len(quote['vendor_packages']), 2)

        # Shipping: default ৳0.00 per vendor package
        self.assertEqual(quote['shipping'], '0.00')

        # Check vendor package 1 (৳2,000 / ৳3,000 * ৳300 = ৳200 discount)
        pkg_v1 = next(p for p in quote['vendor_packages'] if p['vendor_id'] == self.vendor_1.id)
        self.assertEqual(pkg_v1['subtotal'], '2000.00')
        self.assertEqual(pkg_v1['coupon_discount'], '200.00')
        self.assertEqual(pkg_v1['shipping_fee'], '0.00')
        # Total for pkg 1: 2000 - 200 = 1800.00
        self.assertEqual(pkg_v1['total'], '1800.00')

        # Check vendor package 2 (৳1,000 / 3000 * ৳300 = ৳100 discount)
        pkg_v2 = next(p for p in quote['vendor_packages'] if p['vendor_id'] == self.vendor_2.id)
        self.assertEqual(pkg_v2['subtotal'], '1000.00')
        self.assertEqual(pkg_v2['coupon_discount'], '100.00')
        self.assertEqual(pkg_v2['shipping_fee'], '0.00')
        # Total for pkg 2: 1000 - 100 = 900.00
        self.assertEqual(pkg_v2['total'], '900.00')

        # Sum of package totals equals order total: 1800 + 900 = 2700.00
        self.assertEqual(quote['total'], '2700.00')
        self.assertEqual(
            Decimal(pkg_v1['total']) + Decimal(pkg_v2['total']),
            Decimal(quote['total'])
        )

    def test_vendor_scoped_coupon_allocation(self):
        """Vendor-scoped coupon allocates 100% discount to that vendor, 0 to other vendors."""
        items = [
            {'product': self.product_v1.id, 'quantity': 1},  # ৳2,000 (Vendor 1)
            {'product': self.product_v2.id, 'quantity': 1},  # ৳1,000 (Vendor 2)
        ]

        quote = MultiVendorSplitCheckoutService.compute_multi_vendor_quote(
            items_data=items,
            coupon_code='GADGET200',  # Flat ৳200 for Vendor 1
            user=self.customer,
        )

        pkg_v1 = next(p for p in quote['vendor_packages'] if p['vendor_id'] == self.vendor_1.id)
        pkg_v2 = next(p for p in quote['vendor_packages'] if p['vendor_id'] == self.vendor_2.id)

        self.assertEqual(pkg_v1['coupon_discount'], '200.00')
        self.assertEqual(pkg_v2['coupon_discount'], '0.00')

    def test_partial_loyalty_points_allocation(self):
        """Customer redeeming loyalty points has discount proportionally distributed across suborders."""
        items = [
            {'product': self.product_v1.id, 'quantity': 1},  # ৳2,000 (Vendor 1)
            {'product': self.product_v2.id, 'quantity': 1},  # ৳1,000 (Vendor 2)
        ]

        # Redeem 600 points = ৳60.00 discount
        quote = MultiVendorSplitCheckoutService.compute_multi_vendor_quote(
            items_data=items,
            redeem_points=600,
            user=self.customer,
        )

        self.assertEqual(quote['loyalty_points_redeemed'], 600)
        self.assertEqual(quote['loyalty_discount'], '60.00')

        pkg_v1 = next(p for p in quote['vendor_packages'] if p['vendor_id'] == self.vendor_1.id)
        pkg_v2 = next(p for p in quote['vendor_packages'] if p['vendor_id'] == self.vendor_2.id)

        # Vendor 1 (2/3 of 60 = ৳40.00), Vendor 2 (1/3 of 60 = ৳20.00)
        self.assertEqual(pkg_v1['loyalty_discount'], '40.00')
        self.assertEqual(pkg_v2['loyalty_discount'], '20.00')
        self.assertEqual(
            Decimal(pkg_v1['loyalty_discount']) + Decimal(pkg_v2['loyalty_discount']),
            Decimal('60.00')
        )

    def test_place_multi_vendor_order_creates_suborders_with_exact_financials(self):
        """Order placement creates parent Order and SubOrders with exact financial breakdowns."""
        items = [
            {'product': self.product_v1.id, 'quantity': 2},  # 2 x 2000 = ৳4,000 (Vendor 1)
            {'product': self.product_v2.id, 'quantity': 1},  # 1 x 1000 = ৳1,000 (Vendor 2)
        ]

        order = MultiVendorSplitCheckoutService.place_multi_vendor_order(
            user=self.customer,
            address=self.address,
            items_data=items,
            payment_method=Order.PaymentMethod.BKASH,
            coupon_code='SAVE10',  # 10% of 5000 = ৳500 discount (৳400 to V1, ৳100 to V2)
            redeem_points=500,     # 500 pts = ৳50 loyalty discount
            use_wallet=False,
        )

        self.assertEqual(order.subtotal_amount, Decimal('5000.00'))
        self.assertEqual(order.discount_amount, Decimal('500.00'))
        self.assertEqual(order.loyalty_discount_amount, Decimal('50.00'))
        self.assertEqual(order.shipping_fee, Decimal('0.00'))
        # Total: 5000 - 500 - 50 = 4450.00
        self.assertEqual(order.total_amount, Decimal('4450.00'))
        self.assertEqual(order.payment_method, Order.PaymentMethod.BKASH)
        self.assertEqual(order.payment_status, Order.PaymentStatus.UNPAID)

        # Check suborders
        suborders = order.sub_orders.all()
        self.assertEqual(suborders.count(), 2)

        so_v1 = suborders.get(vendor=self.vendor_1)
        self.assertEqual(so_v1.subtotal_amount, Decimal('4000.00'))
        self.assertEqual(so_v1.discount_amount, Decimal('400.00'))
        self.assertEqual(so_v1.shipping_fee, Decimal('0.00'))

        so_v2 = suborders.get(vendor=self.vendor_2)
        self.assertEqual(so_v2.subtotal_amount, Decimal('1000.00'))
        self.assertEqual(so_v2.discount_amount, Decimal('100.00'))
        self.assertEqual(so_v2.shipping_fee, Decimal('0.00'))

        # Sum of suborder totals strictly equals master order total
        self.assertEqual(so_v1.total_amount + so_v2.total_amount, order.total_amount)

        # Inventory decreased
        self.product_v1.refresh_from_db()
        self.product_v2.refresh_from_db()
        self.assertEqual(self.product_v1.stock_quantity, 8)  # 10 - 2
        self.assertEqual(self.product_v2.stock_quantity, 14) # 15 - 1

    def test_combined_single_transaction_payment_flow(self):
        """Combined single bKash payment transitions all multi-vendor suborders to PAID and creates settlements."""
        self.client.force_authenticate(user=self.customer)

        # Place order
        items = [
            {'product': self.product_v1.id, 'quantity': 1},
            {'product': self.product_v2.id, 'quantity': 1},
        ]
        order = MultiVendorSplitCheckoutService.place_multi_vendor_order(
            user=self.customer,
            address=self.address,
            items_data=items,
            payment_method=Order.PaymentMethod.BKASH,
        )

        # 1. Initiate Combined Payment
        init_res = self.client.post(
            f'/api/orders/{order.id}/pay/combined/',
            data={'channel': 'BKASH'},
            format='json',
        )
        self.assertEqual(init_res.status_code, status.HTTP_200_OK)
        init_data = init_res.json()
        self.assertEqual(init_data['channel'], 'BKASH')
        self.assertIn('TRX-BKASH-', init_data['transaction_id'])
        self.assertEqual(init_data['suborders_count'], 2)

        tran_id = init_data['transaction_id']

        # 2. Confirm Combined Payment
        confirm_res = self.client.post(
            f'/api/orders/{order.id}/pay/combined/confirm/',
            data={'channel': 'BKASH', 'transaction_id': tran_id},
            format='json',
        )
        self.assertEqual(confirm_res.status_code, status.HTTP_200_OK)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, Order.PaymentStatus.PAID)
        self.assertEqual(order.status, Order.Status.PAID)
        self.assertEqual(order.transaction_id, tran_id)

        # Verify all sub-orders transitioned to PAID
        for so in order.sub_orders.all():
            self.assertEqual(so.status, Order.Status.PAID)

        # Verify SettlementRecords were generated for both vendors
        settlements = SettlementRecord.objects.filter(sub_order__order=order)
        self.assertEqual(settlements.count(), 2)

        s_v1 = settlements.get(vendor=self.vendor_1)
        self.assertEqual(s_v1.gross_amount, Decimal('2000.00'))
        self.assertEqual(s_v1.platform_fee, Decimal('200.00'))  # 10% fee

        s_v2 = settlements.get(vendor=self.vendor_2)
        self.assertEqual(s_v2.gross_amount, Decimal('1000.00'))
        self.assertEqual(s_v2.platform_fee, Decimal('100.00'))  # 10% fee
