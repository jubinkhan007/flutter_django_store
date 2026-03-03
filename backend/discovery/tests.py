from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from orders.models import Order, SubOrder, OrderItem
from products.models import Category, Product
from vendors.models import Vendor

from .models import ProductAffinity
from .ranking import DiscoveryRanker
from .tasks import compute_product_affinities


User = get_user_model()


class DiscoveryColdStartTest(APITestCase):
    def setUp(self):
        super().setUp()
        self.customer = User.objects.create_user(
            email='cold@example.com',
            username='cold',
            password='pass12345',
            type='CUSTOMER',
        )
        vendor_user = User.objects.create_user(
            email='vend2@example.com',
            username='vend2',
            password='pass12345',
            type='VENDOR',
        )
        self.vendor = Vendor.objects.create(user=vendor_user, store_name='Cold Store')
        self.category = Category.objects.create(name='Shoes', slug='shoes')
        self.p1 = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Runner',
            description='x',
            price='50.00',
            stock_quantity=10,
            is_available=True,
        )
        self.p2 = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Boot',
            description='x',
            price='80.00',
            stock_quantity=0,
            is_available=True,
        )

        order = Order.objects.create(
            customer=self.customer,
            total_amount='50.00',
            status=Order.Status.PAID,
            payment_status=Order.PaymentStatus.PAID,
            payment_method=Order.PaymentMethod.ONLINE,
        )
        sub = SubOrder.objects.create(order=order, vendor=self.vendor, status=Order.Status.PAID)
        OrderItem.objects.create(
            sub_order=sub,
            product=self.p1,
            quantity=1,
            product_title=self.p1.name,
            unit_price='50.00',
        )

    def test_guest_cold_start_returns_non_empty_trending(self):
        resp = self.client.get('/api/discovery/home/')
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertIn('trending', resp.data)
        self.assertGreater(len(resp.data['trending']), 0)


class ProductAffinityTopKTest(APITestCase):
    def setUp(self):
        super().setUp()
        self.customer = User.objects.create_user(
            email='aff@example.com',
            username='aff',
            password='pass12345',
            type='CUSTOMER',
        )
        vendor_user = User.objects.create_user(
            email='vend3@example.com',
            username='vend3',
            password='pass12345',
            type='VENDOR',
        )
        self.vendor = Vendor.objects.create(user=vendor_user, store_name='Affinity Store')
        self.category = Category.objects.create(name='Cat', slug='cat')

    def test_affinity_enforces_top_k(self):
        anchor = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Anchor',
            description='x',
            price='1.00',
            stock_quantity=10,
            is_available=True,
        )
        others = []
        for i in range(60):
            others.append(
                Product.objects.create(
                    vendor=self.vendor,
                    category=self.category,
                    name=f'P{i}',
                    description='x',
                    price='1.00',
                    stock_quantity=10,
                    is_available=True,
                )
            )

        order = Order.objects.create(
            customer=self.customer,
            total_amount='61.00',
            status=Order.Status.PAID,
            payment_status=Order.PaymentStatus.PAID,
            payment_method=Order.PaymentMethod.ONLINE,
        )
        sub = SubOrder.objects.create(order=order, vendor=self.vendor, status=Order.Status.PAID)

        OrderItem.objects.create(
            sub_order=sub,
            product=anchor,
            quantity=1,
            product_title=anchor.name,
            unit_price='1.00',
        )
        for p in others:
            OrderItem.objects.create(
                sub_order=sub,
                product=p,
                quantity=1,
                product_title=p.name,
                unit_price='1.00',
            )

        compute_product_affinities(window_days=365, top_k=50)
        self.assertEqual(ProductAffinity.objects.filter(from_product=anchor).count(), 50)


class AvailabilityGateTest(APITestCase):
    def setUp(self):
        super().setUp()
        user = User.objects.create_user(
            email='vend4@example.com',
            username='vend4',
            password='pass12345',
            type='VENDOR',
        )
        self.vendor = Vendor.objects.create(user=user, store_name='Rank Store')
        self.category = Category.objects.create(name='Rank', slug='rank')

    def test_in_stock_always_ranks_above_oos(self):
        in_stock = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='In',
            description='x',
            price='1.00',
            stock_quantity=5,
            is_available=True,
            avg_rating='1.00',
        )
        oos = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Out',
            description='x',
            price='1.00',
            stock_quantity=0,
            is_available=True,
            avg_rating='5.00',
        )

        ranker = DiscoveryRanker()
        ranked = ranker.rank(Product.objects.filter(id__in=[in_stock.id, oos.id]), limit=2)
        self.assertEqual([p.id for p in ranked], [in_stock.id, oos.id])
