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
