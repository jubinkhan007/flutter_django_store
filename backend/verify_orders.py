"""
Order API Verification Script
Tests the full order lifecycle using Django's internal test Client.
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import Client
from users.models import User
from vendors.models import Vendor
from products.models import Category, Product
from orders.models import Order
from rest_framework_simplejwt.tokens import RefreshToken
import json


def setup():
    """Create test users, vendor, category, and products."""
    # Vendor user
    vendor_user, _ = User.objects.get_or_create(
        email='ordertest_vendor@example.com',
        defaults={'username': 'ordertest_vendor', 'type': 'VENDOR'}
    )
    vendor_user.set_password('testpass123')
    vendor_user.save()

    vendor, _ = Vendor.objects.get_or_create(
        user=vendor_user,
        defaults={'store_name': 'Order Test Store', 'description': 'For testing orders'}
    )

    # Customer user
    customer_user, _ = User.objects.get_or_create(
        email='ordertest_customer@example.com',
        defaults={'username': 'ordertest_customer', 'type': 'CUSTOMER'}
    )
    customer_user.set_password('testpass123')
    customer_user.save()

    # Category + Products
    category, _ = Category.objects.get_or_create(slug='order-test', defaults={'name': 'Order Test'})

    product1, _ = Product.objects.get_or_create(
        name='Test Widget A',
        vendor=vendor,
        defaults={'category': category, 'description': 'Widget A', 'price': 10.00, 'stock_quantity': 50}
    )
    product2, _ = Product.objects.get_or_create(
        name='Test Widget B',
        vendor=vendor,
        defaults={'category': category, 'description': 'Widget B', 'price': 25.50, 'stock_quantity': 30}
    )

    return vendor_user, customer_user, vendor, product1, product2


def run_tests():
    print("=" * 60)
    print("🚀 Order API Verification")
    print("=" * 60)

    vendor_user, customer_user, vendor, product1, product2 = setup()
    print(f"✅ Setup complete: vendor={vendor.store_name}, products={product1.name}, {product2.name}")

    client = Client()
    customer_token = str(RefreshToken.for_user(customer_user).access_token)
    vendor_token = str(RefreshToken.for_user(vendor_user).access_token)
    customer_auth = {'HTTP_AUTHORIZATION': f'Bearer {customer_token}'}
    vendor_auth = {'HTTP_AUTHORIZATION': f'Bearer {vendor_token}'}

    # ── Test 1: Customer places an order ──
    print(f"\n[Test 1] POST /api/orders/place/ — Customer placing an order...")
    resp = client.post(
        '/api/orders/place/',
        data=json.dumps({
            "items": [
                {"product": product1.id, "quantity": 2},
                {"product": product2.id, "quantity": 1}
            ]
        }),
        content_type='application/json',
        **customer_auth
    )
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 201:
        order_data = resp.json()
        order_id = order_data['id']
        print(f"   ✅ SUCCESS! Order #{order_id}, Total={order_data['total_amount']}, Items={len(order_data['items'])}")
        expected_total = (10.00 * 2) + (25.50 * 1)  # 45.50
        print(f"   Expected total: {expected_total}, Got: {float(order_data['total_amount'])}")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")
        return

    # ── Test 2: Stock decreased ──
    print(f"\n[Test 2] Checking stock was decreased...")
    product1.refresh_from_db()
    product2.refresh_from_db()
    print(f"   Widget A stock: {product1.stock_quantity} (expected 48)")
    print(f"   Widget B stock: {product2.stock_quantity} (expected 29)")
    if product1.stock_quantity == 48 and product2.stock_quantity == 29:
        print("   ✅ SUCCESS! Stock correctly decreased.")
    else:
        print("   ❌ FAILED: Stock mismatch.")

    # ── Test 3: Customer views order history ──
    print(f"\n[Test 3] GET /api/orders/ — Customer order history...")
    resp = client.get('/api/orders/', **customer_auth)
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        orders = resp.json()
        print(f"   ✅ SUCCESS! {len(orders)} order(s) returned.")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 4: Customer views single order ──
    print(f"\n[Test 4] GET /api/orders/{order_id}/ — Single order detail...")
    resp = client.get(f'/api/orders/{order_id}/', **customer_auth)
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        print(f"   ✅ SUCCESS! Order #{resp.json()['id']}, Status={resp.json()['status']}")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 5: Vendor sees the order ──
    print(f"\n[Test 5] GET /api/vendors/orders/ — Vendor order list...")
    resp = client.get('/api/vendors/orders/', **vendor_auth)
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        orders = resp.json()
        print(f"   ✅ SUCCESS! Vendor sees {len(orders)} order(s).")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 6: Vendor updates order status to SHIPPED ──
    print(f"\n[Test 6] PATCH /api/vendors/orders/{order_id}/ — Vendor ships the order...")
    resp = client.patch(
        f'/api/vendors/orders/{order_id}/',
        data=json.dumps({"status": "SHIPPED"}),
        content_type='application/json',
        **vendor_auth
    )
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        print(f"   ✅ SUCCESS! Order status updated to: {resp.json()['status']}")
    else:
        print(f"   ❌ FAILED: {resp.content.decode()[:300]}")

    # ── Test 7: Insufficient stock error ──
    print(f"\n[Test 7] POST /api/orders/place/ — Ordering more than available stock...")
    resp = client.post(
        '/api/orders/place/',
        data=json.dumps({
            "items": [{"product": product1.id, "quantity": 9999}]
        }),
        content_type='application/json',
        **customer_auth
    )
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 400:
        print(f"   ✅ SUCCESS! Correctly rejected: {resp.json().get('error', '')[:100]}")
    else:
        print(f"   ❌ FAILED: Expected 400, got {resp.status_code}")

    # ── Cleanup ──
    Order.objects.filter(customer=customer_user).delete()
    Product.objects.filter(vendor=vendor).delete()
    print(f"\n🧹 Cleaned up test data.")
    print("=" * 60)
    print("✅ All tests completed!")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
