from decimal import Decimal
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import AccessToken

from users.models import User, Address
from vendors.models import Vendor
from products.models import Product
from orders.models import Order, SubOrder, OrderItem
from orders.invoice_service import OrderInvoiceService


class OrderInvoiceTest(APITestCase):
    def setUp(self):
        # 1. Customer
        self.customer = User.objects.create_user(
            email="invoice_customer@example.com",
            username="invoice_customer",
            password="Str0ngPassw0rd!",
            type=User.Types.CUSTOMER,
        )

        # 2. Other Customer
        self.other_customer = User.objects.create_user(
            email="other_customer@example.com",
            username="other_customer",
            password="Str0ngPassw0rd!",
            type=User.Types.CUSTOMER,
        )

        # 3. Vendor
        self.vendor_user = User.objects.create_user(
            email="invoice_vendor@example.com",
            username="invoice_vendor",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="Apex Footwear",
            description="Official apex store",
            is_approved=True,
        )

        # 4. Product
        self.product = Product.objects.create(
            vendor=self.vendor,
            name="Apex Leather Shoes",
            price=Decimal("1500.00"),
            stock_quantity=20,
            is_available=True,
        )

        # 5. Address
        self.address = Address.objects.create(
            user=self.customer,
            label="Home",
            phone_number="01812345678",
            address_line="House 12, Road 4, Dhanmondi",
            area="Dhanmondi",
            city="Dhaka",
            is_default=True,
        )

        # 6. Order + SubOrder + OrderItem
        self.order = Order.objects.create(
            customer=self.customer,
            delivery_address=self.address,
            subtotal_amount=Decimal("3000.00"),
            discount_amount=Decimal("200.00"),
            wallet_amount_applied=Decimal("500.00"),
            total_amount=Decimal("2800.00"),
            status=Order.Status.PAID,
            payment_method=Order.PaymentMethod.ONLINE,
            payment_status=Order.PaymentStatus.PAID,
            transaction_id="SSL_TXN_9918231",
        )

        self.sub_order = SubOrder.objects.create(
            order=self.order,
            vendor=self.vendor,
            status=Order.Status.PAID,
            fulfillment_type=SubOrder.FulfillmentType.LOCAL,
        )

        self.item = OrderItem.objects.create(
            sub_order=self.sub_order,
            product=self.product,
            product_title="Apex Leather Shoes",
            variant_name="Size 42 / Brown",
            sku="APX-SH-42-BRN",
            unit_price=Decimal("1500.00"),
            quantity=2,
            tax=Decimal("150.00"),
            discount=Decimal("100.00"),
        )

    def test_invoice_service_generates_valid_pdf_bytes(self):
        pdf_bytes = OrderInvoiceService.generate_invoice_pdf(self.order)
        self.assertIsInstance(pdf_bytes, bytes)
        self.assertTrue(len(pdf_bytes) > 1000)
        # PDF files always begin with the magic header %PDF-
        self.assertTrue(pdf_bytes.startswith(b"%PDF-"))

    def test_customer_can_download_invoice(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.get(f"/api/orders/{self.order.id}/invoice/pdf/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp["Content-Type"], "application/pdf")
        self.assertIn("inline; filename=", resp["Content-Disposition"])
        self.assertTrue(resp.content.startswith(b"%PDF-"))

    def test_other_customer_cannot_download_invoice(self):
        self.client.force_authenticate(user=self.other_customer)
        resp = self.client.get(f"/api/orders/{self.order.id}/invoice/pdf/")
        self.assertEqual(resp.status_code, 403)

    def test_vendor_can_download_suborder_invoice(self):
        self.client.force_authenticate(user=self.vendor_user)
        resp = self.client.get(f"/api/orders/{self.order.id}/invoice/pdf/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp["Content-Type"], "application/pdf")

    def test_download_invoice_via_query_token(self):
        # Unauthenticated client using valid JWT access token in query param
        token = str(AccessToken.for_user(self.customer))
        resp = self.client.get(f"/api/orders/{self.order.id}/invoice/pdf/?token={token}")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp["Content-Type"], "application/pdf")

    def test_download_invoice_with_invalid_token_fails(self):
        resp = self.client.get(f"/api/orders/{self.order.id}/invoice/pdf/?token=invalid.jwt.token")
        self.assertEqual(resp.status_code, 401)

    def test_invoice_verification_endpoint(self):
        resp = self.client.get(f"/api/orders/{self.order.id}/invoice/verify/")
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.data["valid"])
        self.assertEqual(resp.data["order_id"], self.order.id)
        self.assertEqual(resp.data["payment_status"], "PAID")
        self.assertEqual(resp.data["sub_orders_count"], 1)
