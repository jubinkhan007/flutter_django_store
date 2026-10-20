from decimal import Decimal
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase
from loyalty.models import LoyaltyAccount, LoyaltyTransaction
from products.models import Category, Product
from vendors.models import Vendor
from users.models import Address
from orders.models import Order

User = get_user_model()


class LoyaltyProgramTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='loyaltyuser',
            email='loyalty@test.com',
            password='Password123!',
        )
        self.client.force_authenticate(user=self.user)

        self.vendor_user = User.objects.create_user(
            username='vendoruser',
            email='vendor@test.com',
            password='Password123!',
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name='Loyalty Test Store',
        )
        self.category = Category.objects.create(name='Electronics', slug='electronics')
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Test Earphones',
            description='Test wireless earphones',
            price=Decimal('1000.00'),
            stock_quantity=50,
            is_available=True,
        )
        self.address = Address.objects.create(
            user=self.user,
            label='Home',
            phone_number='01711111111',
            address_line='House 1, Road 2',
            city='Dhaka',
            area='Gulshan',
        )

    def test_loyalty_account_creation_and_tiers(self):
        account, created = LoyaltyAccount.objects.get_or_create(user=self.user)
        self.assertEqual(account.tier, LoyaltyAccount.Tier.BRONZE)
        self.assertEqual(account.points_balance, 0)
        self.assertEqual(account.tier_multiplier, 1.0)
        self.assertEqual(account.points_value_bdt, Decimal('0.00'))

        # Earn 1000 BDT purchase -> 100 points
        pts = account.earn_points_for_purchase(Decimal('1000.00'))
        self.assertEqual(pts, 100)
        self.assertEqual(account.points_balance, 100)
        self.assertEqual(account.points_value_bdt, Decimal('10.00'))
        self.assertEqual(account.tier, LoyaltyAccount.Tier.BRONZE)

        # Earn enough to reach Silver (500 pts)
        account.earn_points_for_purchase(Decimal('4000.00'))  # 400 pts -> total 500
        account.refresh_from_db()
        self.assertEqual(account.tier, LoyaltyAccount.Tier.SILVER)
        self.assertEqual(account.tier_multiplier, 1.2)

    def test_redeem_points_and_quote_api(self):
        account, _ = LoyaltyAccount.objects.get_or_create(user=self.user)
        account.points_balance = 300
        account.lifetime_points_earned = 300
        account.save()

        # Quote redemption endpoint
        response = self.client.post('/api/loyalty/quote-redemption/', {'points': 150})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['points'], 150)
        self.assertEqual(response.data['discount_amount'], '15.00')
        self.assertEqual(response.data['remaining_balance'], 150)

        # Actual redemption
        discount = account.redeem_points(150)
        self.assertEqual(discount, Decimal('15.00'))
        self.assertEqual(account.points_balance, 150)
        self.assertEqual(account.lifetime_points_redeemed, 150)

        # Verify transaction logged
        tx = LoyaltyTransaction.objects.filter(account=account, transaction_type=LoyaltyTransaction.Type.REDEEM).first()
        self.assertIsNotNone(tx)
        self.assertEqual(tx.points, -150)

    def test_loyalty_summary_and_transactions_endpoints(self):
        account, _ = LoyaltyAccount.objects.get_or_create(user=self.user)
        account.points_balance = 250
        account.lifetime_points_earned = 250
        account.save()

        LoyaltyTransaction.objects.create(
            account=account,
            transaction_type=LoyaltyTransaction.Type.EARN,
            points=250,
            balance_after=250,
            description='Initial bonus',
        )

        # Summary API
        res = self.client.get('/api/loyalty/summary/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['points_balance'], 250)
        self.assertEqual(res.data['points_value_bdt'], '25.00')
        self.assertEqual(res.data['tier'], 'BRONZE')
        self.assertIn('next_tier_info', res.data)

        # Transactions API
        res_tx = self.client.get('/api/loyalty/transactions/')
        tx_list = res_tx.data if isinstance(res_tx.data, list) else res_tx.data.get('results', [])
        self.assertEqual(len(tx_list), 1)
        self.assertEqual(tx_list[0]['points'], 250)

    def test_checkout_quote_and_order_with_loyalty_redemption(self):
        account, _ = LoyaltyAccount.objects.get_or_create(user=self.user)
        account.points_balance = 200  # worth ৳20.00
        account.lifetime_points_earned = 200
        account.save()

        quote_payload = {
            'items': [{'product': self.product.id, 'quantity': 1}],
            'address_id': self.address.id,
            'redeem_points': 100,  # ৳10.00 discount
        }
        quote_res = self.client.post('/api/orders/quote/', quote_payload, format='json')
        self.assertEqual(quote_res.status_code, status.HTTP_200_OK)
        self.assertEqual(quote_res.data['subtotal'], '1000.00')
        self.assertEqual(quote_res.data['loyalty_points_redeemed'], 100)
        self.assertEqual(quote_res.data['loyalty_discount'], '10.00')
        self.assertEqual(quote_res.data['total'], '990.00')

        # Place order with 100 points redeemed
        order_payload = {
            'items': [{'product': self.product.id, 'quantity': 1}],
            'address_id': self.address.id,
            'payment_method': Order.PaymentMethod.COD,
            'redeem_points': 100,
        }
        order_res = self.client.post('/api/orders/place/', order_payload, format='json')
        self.assertEqual(order_res.status_code, status.HTTP_201_CREATED)
        order_id = order_res.data['id']

        order = Order.objects.get(id=order_id)
        self.assertEqual(order.subtotal_amount, Decimal('1000.00'))
        self.assertEqual(order.loyalty_points_redeemed, 100)
        self.assertEqual(order.loyalty_discount_amount, Decimal('10.00'))
        self.assertEqual(order.total_amount, Decimal('990.00'))

        account.refresh_from_db()
        # Initial: 200 - 100 (redeemed) + 99 (earned on 990 BDT purchase) = 199
        self.assertEqual(account.points_balance, 199)

        # Cancel order and verify points refunded
        cancel_res = self.client.post(f'/api/orders/{order.id}/cancel/')
        self.assertEqual(cancel_res.status_code, status.HTTP_200_OK)

        account.refresh_from_db()
        # 199 + 100 refunded = 299
        self.assertEqual(account.points_balance, 299)
