from decimal import Decimal
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from products.models import Category, Product
from returns.models import ReturnPolicy
from users.models import Address, User
from vendors.models import Vendor


class DeliveryEstimateApiTest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="shopper@example.com",
            username="shopper",
            password="StrongPassword123!",
        )
        self.address = Address.objects.create(
            user=self.user,
            label="Home",
            phone_number="01700000000",
            address_line="House 12, Road 4",
            area="Zindabazar",
            city="Sylhet",
            is_default=True,
        )

        self.vendor_user = User.objects.create_user(
            email="vendor_logistics@example.com",
            username="vendor_logistics",
            password="StrongPassword123!",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="Gadget World",
            is_approved=True,
            is_live=True,
        )

        self.category = Category.objects.create(
            name="Electronics",
            slug="electronics",
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name="Wireless Earbuds",
            price=Decimal("850.00"),
            stock_quantity=50,
            is_available=True,
        )

        self.expensive_product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name="Mechanical Keyboard",
            price=Decimal("3500.00"),
            stock_quantity=20,
            is_available=True,
        )

        ReturnPolicy.objects.create(
            name="Standard 7 Days Policy",
            product=self.product,
            return_window_days=7,
            allow_return=True,
            is_active=True,
        )

        self.url = reverse('logistics-estimate')

    def test_missing_product_id_returns_400(self):
        res = self.client.get(self.url)
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('product_id query parameter is required', res.data['error'])

    def test_nonexistent_product_returns_404(self):
        res = self.client.get(self.url, {'product_id': 999999})
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_intra_city_estimate_dhaka_to_dhaka(self):
        res = self.client.get(self.url, {
            'product_id': self.product.id,
            'city': 'Dhaka',
            'area': 'Gulshan-2',
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data

        self.assertTrue(data['destination']['is_inside_city'])
        self.assertEqual(data['destination']['city'], 'Dhaka')
        self.assertEqual(data['destination']['area'], 'Gulshan-2')
        self.assertEqual(data['origin']['vendor_city'], 'Dhaka')

        options = {opt['code']: opt for opt in data['options']}
        self.assertIn('STANDARD', options)
        self.assertIn('EXPRESS', options)

        # Standard inside Dhaka: ৳60, 2-3 days
        std = options['STANDARD']
        self.assertEqual(std['fee'], 60.00)
        self.assertEqual(std['fee_display'], '৳60')
        self.assertFalse(std['is_free'])
        self.assertEqual(std['min_days'], 2)
        self.assertEqual(std['max_days'], 3)

        # Express inside Dhaka: ৳120, 1-2 days
        exp = options['EXPRESS']
        self.assertEqual(exp['fee'], 120.00)
        self.assertEqual(exp['fee_display'], '৳120')
        self.assertEqual(exp['min_days'], 1)
        self.assertEqual(exp['max_days'], 2)

        # Trust Badges
        self.assertTrue(data['cash_on_delivery']['is_available'])
        self.assertEqual(data['return_policy']['return_window_days'], 7)
        self.assertTrue(data['return_policy']['allow_return'])

    def test_inter_city_estimate_dhaka_to_chittagong(self):
        res = self.client.get(self.url, {
            'product_id': self.product.id,
            'city': 'Chittagong',
            'area': 'Agrabad',
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data

        self.assertFalse(data['destination']['is_inside_city'])
        self.assertEqual(data['destination']['city'], 'Chittagong')

        options = {opt['code']: opt for opt in data['options']}
        # Standard outside Dhaka: ৳120, 3-5 days
        std = options['STANDARD']
        self.assertEqual(std['fee'], 120.00)
        self.assertEqual(std['fee_display'], '৳120')
        self.assertEqual(std['min_days'], 3)
        self.assertEqual(std['max_days'], 5)

        # Express outside Dhaka: ৳180, 2-3 days
        exp = options['EXPRESS']
        self.assertEqual(exp['fee'], 180.00)
        self.assertEqual(exp['fee_display'], '৳180')
        self.assertEqual(exp['min_days'], 2)
        self.assertEqual(exp['max_days'], 3)

    def test_free_shipping_threshold_qualification(self):
        # Product price is ৳3,500 >= threshold ৳2,000
        res = self.client.get(self.url, {
            'product_id': self.expensive_product.id,
            'city': 'Dhaka',
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data

        self.assertTrue(data['qualifies_for_free_shipping'])
        options = {opt['code']: opt for opt in data['options']}
        std = options['STANDARD']
        self.assertTrue(std['is_free'])
        self.assertEqual(std['fee'], 0.00)
        self.assertEqual(std['fee_display'], 'FREE')
        self.assertEqual(std['title'], 'Free Standard Delivery')

    def test_authenticated_user_default_address_fallback(self):
        self.client.force_authenticate(user=self.user)
        # Omit city parameter; should auto-resolve to self.address.city ('Sylhet')
        res = self.client.get(self.url, {'product_id': self.product.id})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data

        self.assertEqual(data['destination']['city'], 'Sylhet')
        self.assertEqual(data['destination']['area'], 'Zindabazar')
        self.assertFalse(data['destination']['is_inside_city'])
