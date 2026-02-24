from decimal import Decimal

from rest_framework.test import APITestCase

from coupons.models import Coupon
from products.models import Product, Category
from users.models import User, Address
from vendors.models import Vendor


class CouponAvailableApiTest(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            email="coupon_customer@example.com",
            username="coupon_customer",
            password="Str0ngPassw0rd!",
            type=User.Types.CUSTOMER,
        )

        self.vendor_user_1 = User.objects.create_user(
            email="vendor1@example.com",
            username="vendor1",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor_user_2 = User.objects.create_user(
            email="vendor2@example.com",
            username="vendor2",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )

        self.vendor1 = Vendor.objects.create(
            user=self.vendor_user_1,
            store_name="Shop One",
            description="Test",
            is_approved=True,
        )
        self.vendor2 = Vendor.objects.create(
            user=self.vendor_user_2,
            store_name="Shop Two",
            description="Test",
            is_approved=True,
        )

        self.category = Category.objects.create(name="Cat", slug="cat", description="")
        self.p1 = Product.objects.create(
            vendor=self.vendor1,
            category=self.category,
            name="P1",
            description="",
            price=Decimal("10.00"),
            stock_quantity=10,
            is_available=True,
        )
        self.p2 = Product.objects.create(
            vendor=self.vendor2,
            category=self.category,
            name="P2",
            description="",
            price=Decimal("20.00"),
            stock_quantity=10,
            is_available=True,
        )

        Coupon.objects.create(
            code="GLOBAL10",
            scope=Coupon.Scope.GLOBAL,
            discount_type=Coupon.DiscountType.PERCENT,
            discount_value=Decimal("10.00"),
            is_active=True,
        )

        Coupon.objects.create(
            code="V1FIX5",
            scope=Coupon.Scope.VENDOR,
            vendor=self.vendor1,
            discount_type=Coupon.DiscountType.FIXED,
            discount_value=Decimal("5.00"),
            is_active=True,
        )

        Coupon.objects.create(
            code="MIN100",
            scope=Coupon.Scope.GLOBAL,
            discount_type=Coupon.DiscountType.FIXED,
            discount_value=Decimal("10.00"),
            min_order_amount=Decimal("100.00"),
            is_active=True,
        )

    def test_available_coupons_returns_only_applicable(self):
        self.client.force_authenticate(user=self.customer)

        resp = self.client.post(
            "/api/coupons/available/",
            data={"items": [{"product": self.p1.id, "quantity": 1}]},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)

        codes = [c["code"] for c in resp.data]
        self.assertIn("GLOBAL10", codes)
        self.assertIn("V1FIX5", codes)
        self.assertNotIn("MIN100", codes)

    def test_vendor_coupon_can_apply_in_multi_vendor_cart(self):
        self.client.force_authenticate(user=self.customer)

        resp = self.client.post(
            "/api/coupons/available/",
            data={
                "items": [
                    {"product": self.p1.id, "quantity": 1},
                    {"product": self.p2.id, "quantity": 1},
                ]
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        codes = [c["code"] for c in resp.data]
        self.assertIn("V1FIX5", codes)
