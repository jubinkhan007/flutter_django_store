from decimal import Decimal

from django.test import TestCase
from django.utils import timezone

from users.models import User, Address
from vendors.models import Vendor, LedgerEntry, SettlementRecord, PayoutRequest
from vendors.financial_service import FinancialService
from products.models import Category, Product
from orders.models import Order, SubOrder, OrderItem


class FinancialServiceTests(TestCase):
    def setUp(self):
        self.vendor_user = User.objects.create_user(
            email='vendor@example.com',
            username='vendor',
            password='pass1234',
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name='Vendor Store',
            description='Test vendor',
            is_approved=True,
            balance=Decimal('0.00'),
            available_balance=Decimal('0.00'),
            pending_balance=Decimal('0.00'),
            held_balance=Decimal('0.00'),
        )

        self.customer = User.objects.create_user(
            email='customer@example.com',
            username='customer',
            password='pass1234',
            type=User.Types.CUSTOMER,
        )
        self.address = Address.objects.create(
            user=self.customer,
            label='Home',
            phone_number='01700000000',
            address_line='123 Street',
            area='Area',
            city='City',
            is_default=True,
        )

        self.category = Category.objects.create(
            name='Electronics',
            slug='electronics',
            description='',
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Headphones',
            description='',
            price=Decimal('100.00'),
            stock_quantity=10,
            is_available=True,
        )

    def _create_paid_delivered_suborder(self):
        order = Order.objects.create(
            customer=self.customer,
            delivery_address=self.address,
            subtotal_amount=Decimal('100.00'),
            discount_amount=Decimal('0.00'),
            total_amount=Decimal('100.00'),
            status=Order.Status.PAID,
            payment_method=Order.PaymentMethod.ONLINE,
            payment_status=Order.PaymentStatus.PAID,
        )
        sub = SubOrder.objects.create(order=order, vendor=self.vendor, status=Order.Status.PAID)
        OrderItem.objects.create(
            sub_order=sub,
            product=self.product,
            quantity=2,
            product_title='Headphones',
            unit_price=Decimal('50.00'),
            tax=Decimal('0.00'),
            discount=Decimal('0.00'),
            image_url='',
        )
        sub.advance_status(Order.Status.SHIPPED)
        sub.advance_status(Order.Status.DELIVERED)
        return sub

    def test_accrue_earnings_idempotent(self):
        sub = self._create_paid_delivered_suborder()

        record1 = FinancialService.accrue_earnings(sub)
        record2 = FinancialService.accrue_earnings(sub)
        self.assertEqual(record1.id, record2.id)

        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.pending_balance, Decimal('90.00'))  # 10% fee on 100 gross
        self.assertEqual(LedgerEntry.objects.filter(vendor=self.vendor).count(), 1)
        self.assertTrue(SettlementRecord.objects.filter(sub_order=sub).exists())

    def test_payout_hold_cannot_overdraw_available(self):
        # Seed available balance
        self.vendor.available_balance = Decimal('50.00')
        self.vendor.balance = Decimal('50.00')
        self.vendor.save(update_fields=['available_balance', 'balance'])

        payout1 = PayoutRequest.objects.create(
            vendor=self.vendor,
            amount=Decimal('30.00'),
            bank_details='Bank: Test',
        )
        FinancialService.request_payout_hold(self.vendor, Decimal('30.00'), payout1)

        self.vendor.refresh_from_db()
        self.assertEqual(self.vendor.available_balance, Decimal('20.00'))
        self.assertEqual(self.vendor.held_balance, Decimal('30.00'))

        payout2 = PayoutRequest.objects.create(
            vendor=self.vendor,
            amount=Decimal('25.00'),
            bank_details='Bank: Test',
        )
        with self.assertRaises(ValueError):
            FinancialService.request_payout_hold(self.vendor, Decimal('25.00'), payout2)

    def test_settlement_release_moves_pending_to_available(self):
        sub = self._create_paid_delivered_suborder()
        record = FinancialService.accrue_earnings(sub)

        # Force settlement due today
        record.settlement_date = timezone.now().date()
        record.save(update_fields=['settlement_date'])

        FinancialService.release_settlement(record)

        self.vendor.refresh_from_db()
        record.refresh_from_db()

        self.assertEqual(record.status, SettlementRecord.Status.RELEASED)
        self.assertEqual(self.vendor.pending_balance, Decimal('0.00'))
        self.assertEqual(self.vendor.available_balance, Decimal('90.00'))

        # Two ledger entries for the release + the original accrue entry
        self.assertEqual(LedgerEntry.objects.filter(vendor=self.vendor).count(), 3)

