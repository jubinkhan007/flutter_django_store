from decimal import Decimal

from rest_framework.test import APITestCase

from users.models import User, Address
from vendors.models import Vendor
from products.models import Product


class CashOnDeliveryTest(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            email="customer@example.com",
            username="customer",
            password="Str0ngPassw0rd!",
            type=User.Types.CUSTOMER,
        )
        self.vendor_user = User.objects.create_user(
            email="vendor@example.com",
            username="vendor",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="Test Store",
            description="Test",
            is_approved=True,
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=None,
            name="Test Product",
            description="Test",
            price=Decimal("9.99"),
            stock_quantity=10,
            is_available=True,
        )
        self.address = Address.objects.create(
            user=self.customer,
            label="Home",
            phone_number="01700000000",
            address_line="123 Main St",
            area="Area",
            city="Dhaka",
            is_default=True,
        )

    def test_place_order_cod_sets_payment_method_and_disables_pay(self):
        self.client.force_authenticate(user=self.customer)

        resp = self.client.post(
            "/api/orders/place/",
            data={
                "items": [{"product": self.product.id, "quantity": 2}],
                "address_id": self.address.id,
                "payment_method": "COD",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(resp.data.get("payment_method"), "COD")

        order_id = resp.data["id"]
        pay_resp = self.client.post(f"/api/orders/{order_id}/pay/", data={}, format="json")
        self.assertEqual(pay_resp.status_code, 400, pay_resp.data)


class WalletCheckoutTest(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            email="wallet_customer@example.com",
            username="wallet_customer",
            password="Str0ngPassw0rd!",
            type=User.Types.CUSTOMER,
            wallet_balance=Decimal("50.00"),
        )
        self.vendor_user = User.objects.create_user(
            email="vendor2@example.com",
            username="vendor2",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="Test Store 2",
            description="Test",
            is_approved=True,
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=None,
            name="Test Product 2",
            description="Test",
            price=Decimal("20.00"),
            stock_quantity=10,
            is_available=True,
        )
        self.address = Address.objects.create(
            user=self.customer,
            label="Home",
            phone_number="01700000000",
            address_line="456 Elm St",
            area="Area",
            city="Dhaka",
            is_default=True,
        )

    def test_quote_with_wallet(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/orders/quote/",
            data={
                "items": [{"product": self.product.id, "quantity": 1}],
                "address_id": self.address.id,
                "use_wallet": True,
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(Decimal(str(resp.data["user_wallet_balance"])), Decimal("50.00"))
        self.assertTrue(Decimal(str(resp.data["wallet_amount_applied"])) > Decimal("0.00"))
        self.assertEqual(Decimal(str(resp.data["payable_amount"])), Decimal("0.00"))
        self.assertTrue(resp.data["is_fully_covered_by_wallet"])

    def test_place_order_full_wallet_payment(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/orders/place/",
            data={
                "items": [{"product": self.product.id, "quantity": 1}],
                "address_id": self.address.id,
                "payment_method": "ONLINE",
                "use_wallet": True,
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        # Should be converted to WALLET payment method and marked PAID
        self.assertEqual(resp.data.get("payment_method"), "WALLET")
        self.assertEqual(resp.data.get("payment_status"), "PAID")
        self.assertEqual(resp.data.get("status"), "PAID")
        self.customer.refresh_from_db()
        # Initial 50.00 minus 20.00 product = 30.00
        self.assertEqual(self.customer.wallet_balance, Decimal("30.00"))

    def test_place_order_split_cod_payment(self):
        # Set wallet balance lower than product price
        self.customer.wallet_balance = Decimal("10.00")
        self.customer.save()

        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/orders/place/",
            data={
                "items": [{"product": self.product.id, "quantity": 1}],
                "address_id": self.address.id,
                "payment_method": "COD",
                "use_wallet": True,
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(resp.data.get("payment_method"), "COD")
        self.assertEqual(Decimal(str(resp.data.get("wallet_amount_applied"))), Decimal("10.00"))
        self.assertEqual(Decimal(str(resp.data.get("payable_amount"))), Decimal("10.00"))
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.wallet_balance, Decimal("0.00"))

    def test_order_cancellation_refunds_wallet_balance(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/orders/place/",
            data={
                "items": [{"product": self.product.id, "quantity": 1}],
                "address_id": self.address.id,
                "payment_method": "ONLINE",
                "use_wallet": True,
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        order_id = resp.data["id"]
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.wallet_balance, Decimal("30.00"))

        # Now cancel order
        cancel_resp = self.client.post(f"/api/orders/{order_id}/cancel/", format="json")
        self.assertEqual(cancel_resp.status_code, 200, cancel_resp.data)
        self.customer.refresh_from_db()
        # Refunded back 20.00 -> 50.00
        self.assertEqual(self.customer.wallet_balance, Decimal("50.00"))

    def test_customer_wallet_endpoint(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.get("/api/auth/wallet/")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(Decimal(str(resp.data["wallet_balance"])), Decimal("50.00"))
        self.assertIn("transactions", resp.data)
