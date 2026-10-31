from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from products.models import Category, Product, SearchQueryHistory
from vendors.models import Vendor

User = get_user_model()


class AdvancedProductSearchTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='search_user',
            email='search_user@example.com',
            password='Password123!',
        )
        self.vendor_user = User.objects.create_user(
            username='search_vuser',
            email='search_vuser@example.com',
            password='Password123!',
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name='Electro World',
        )
        self.cat_electronics = Category.objects.create(
            name='Electronics',
            slug='electronics',
        )
        self.cat_fashion = Category.objects.create(
            name='Fashion',
            slug='fashion',
        )

        self.p1 = Product.objects.create(
            vendor=self.vendor,
            category=self.cat_electronics,
            name='Apple iPhone 15 Pro',
            brand='Apple',
            description='Flagship titanium smartphone',
            price=Decimal('1200.00'),
            discount_percent=10,
            stock_quantity=15,
            avg_rating=Decimal('4.8'),
            review_count=85,
        )
        self.p2 = Product.objects.create(
            vendor=self.vendor,
            category=self.cat_electronics,
            name='Samsung Galaxy S24 Ultra',
            brand='Samsung',
            description='AI powered flagship phone',
            price=Decimal('1150.00'),
            discount_percent=25,
            stock_quantity=8,
            avg_rating=Decimal('4.6'),
            review_count=60,
        )
        self.p3 = Product.objects.create(
            vendor=self.vendor,
            category=self.cat_electronics,
            name='Sony WH-1000XM5 Headphones',
            brand='Sony',
            description='Wireless noise cancelling headphones',
            price=Decimal('350.00'),
            discount_percent=15,
            stock_quantity=0,  # Out of stock
            avg_rating=Decimal('4.9'),
            review_count=120,
        )

    def test_brand_and_in_stock_filtering(self):
        # Filter brand=Apple
        res = self.client.get('/api/products/?brand=Apple')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)
        self.assertEqual(res.data[0]['name'], 'Apple iPhone 15 Pro')

        # Filter in_stock=true (excludes Sony)
        res_instock = self.client.get('/api/products/?in_stock=true')
        self.assertEqual(res_instock.status_code, status.HTTP_200_OK)
        names = [p['name'] for p in res_instock.data]
        self.assertIn('Apple iPhone 15 Pro', names)
        self.assertIn('Samsung Galaxy S24 Ultra', names)
        self.assertNotIn('Sony WH-1000XM5 Headphones', names)

    def test_rating_and_discount_filtering(self):
        # min_discount=20 -> only Samsung (25%)
        res = self.client.get('/api/products/?min_discount=20')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)
        self.assertEqual(res.data[0]['name'], 'Samsung Galaxy S24 Ultra')

        # min_rating=4.7 -> Apple (4.8) and Sony (4.9)
        res_rating = self.client.get('/api/products/?min_rating=4.7')
        self.assertEqual(res_rating.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_rating.data), 2)

    def test_sorting_by_discount_and_rating(self):
        # Sort by discount
        res = self.client.get('/api/products/?sort=discount')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data[0]['name'], 'Samsung Galaxy S24 Ultra')  # 25%

        # Sort by price_desc
        res_price = self.client.get('/api/products/?sort=price_desc')
        self.assertEqual(res_price.status_code, status.HTTP_200_OK)
        self.assertEqual(res_price.data[0]['name'], 'Apple iPhone 15 Pro')

    def test_facets_endpoint(self):
        res = self.client.get('/api/products/facets/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data

        self.assertEqual(data['total_count'], 3)
        self.assertEqual(data['in_stock_count'], 2)
        self.assertEqual(len(data['brands']), 3)
        brand_names = [b['name'] for b in data['brands']]
        self.assertIn('Apple', brand_names)
        self.assertIn('Samsung', brand_names)
        self.assertIn('Sony', brand_names)
        self.assertEqual(data['price_range']['min'], 350.0)
        self.assertEqual(data['price_range']['max'], 1200.0)

    def test_search_history_api(self):
        self.client.force_authenticate(user=self.user)

        # POST search query
        res_post = self.client.post('/api/products/search/history/', {'query': 'wireless earbuds'})
        self.assertEqual(res_post.status_code, status.HTTP_200_OK)

        # GET history
        res_get = self.client.get('/api/products/search/history/')
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)
        self.assertIn('wireless earbuds', res_get.data['recent'])

        # DELETE history
        res_del = self.client.delete('/api/products/search/history/')
        self.assertEqual(res_del.status_code, status.HTTP_200_OK)

        res_after = self.client.get('/api/products/search/history/')
        self.assertEqual(len(res_after.data['recent']), 0)

    def test_search_suggestions_with_brands(self):
        res = self.client.get('/api/products/search/suggestions/?q=App')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        types = [item['type'] for item in res.data['results']]
        labels = [item['label'] for item in res.data['results']]
        self.assertIn('BRAND', types)
        self.assertIn('Apple', labels)
