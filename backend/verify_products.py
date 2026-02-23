"""
Product API Verification Script
Uses Django's test Client internally (no need for a running server).
"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import Client
from django.test.utils import override_settings
from users.models import User
from vendors.models import Vendor
from products.models import Category, Product
from rest_framework_simplejwt.tokens import RefreshToken
import json


def run_tests():
    print("=" * 60)
    print("🚀 Product API Verification")
    print("=" * 60)

    # ── Setup: Create test user + vendor + category ──
    user, created = User.objects.get_or_create(
        email='producttest@example.com',
        defaults={'username': 'producttest', 'type': 'VENDOR'}
    )
    if created:
        user.set_password('testpass123')
        user.save()
        print(f"✅ Created test user: {user.email}")
    else:
        print(f"✅ Using existing test user: {user.email}")

    vendor, _ = Vendor.objects.get_or_create(
        user=user,
        defaults={'store_name': 'Product Test Store', 'description': 'For testing'}
    )
    print(f"✅ Vendor profile ready: {vendor.store_name}")

    category, _ = Category.objects.get_or_create(
        slug='tech-gadgets',
        defaults={'name': 'Tech Gadgets'}
    )
    print(f"✅ Category ready: {category.name}")

    # Get JWT token
    token = str(RefreshToken.for_user(user).access_token)

    client = Client()
    auth = {'HTTP_AUTHORIZATION': f'Bearer {token}'}

    # ── Test 1: Vendor creates a product ──
    print(f"\n[Test 1] POST /api/vendors/products/ — Creating a product...")
    resp = client.post(
        '/api/vendors/products/',
        data=json.dumps({
            "category": category.id,
            "name": "Super Fast Charger",
            "description": "Charges your phone in 5 minutes.",
            "price": "29.99",
            "stock_quantity": 100
        }),
        content_type='application/json',
        **auth
    )
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 201:
        data = resp.json()
        product_id = data['id']
        print(f"   ✅ SUCCESS! Product ID={product_id}, Name={data['name']}, Price={data['price']}")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")
        return

    # ── Test 2: Public can browse products ──
    print(f"\n[Test 2] GET /api/products/ — Public product listing (no auth)...")
    resp = client.get('/api/products/')
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        products = resp.json()
        print(f"   ✅ SUCCESS! {len(products)} product(s) returned.")
        found = any(p['id'] == product_id for p in products)
        print(f"   {'✅' if found else '❌'} New product {'found' if found else 'NOT found'} in listing.")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 3: Vendor updates their product ──
    print(f"\n[Test 3] PUT /api/vendors/products/{product_id}/ — Updating product...")
    resp = client.put(
        f'/api/vendors/products/{product_id}/',
        data=json.dumps({
            "category": category.id,
            "name": "Super Fast Charger Pro",
            "description": "Charges your phone in 2 minutes!",
            "price": "34.99",
            "stock_quantity": 50
        }),
        content_type='application/json',
        **auth
    )
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"   ✅ SUCCESS! Name={data['name']}, Price={data['price']}, Stock={data['stock_quantity']}")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 4: Public can view single product ──
    print(f"\n[Test 4] GET /api/products/{product_id}/ — Single product detail...")
    resp = client.get(f'/api/products/{product_id}/')
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"   ✅ SUCCESS! Name={data['name']}, in_stock={data['in_stock']}")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 5: Category listing ──
    print(f"\n[Test 5] GET /api/products/categories/ — Category listing...")
    resp = client.get('/api/products/categories/')
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        cats = resp.json()
        print(f"   ✅ SUCCESS! {len(cats)} category(ies) returned.")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Cleanup ──
    Product.objects.filter(vendor=vendor).delete()
    print(f"\n🧹 Cleaned up test products.")
    print("=" * 60)
    print("✅ All tests completed!")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
