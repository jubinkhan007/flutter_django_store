from datetime import timedelta
from decimal import Decimal

from django.utils import timezone
from rest_framework.test import APITestCase

from orders.models import Order, OrderItem
from products.models import Category, Product
from returns.models import ReturnItem, ReturnPolicy, ReturnRequest
from returns.services import escalate_overdue_returns
from users.models import Address, User
from vendors.models import Vendor


class ReturnsFlowTest(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            email="customer_rma@example.com",
            username="customer_rma",
            password="Str0ngPassw0rd!",
            type=User.Types.CUSTOMER,
        )
        self.vendor_user = User.objects.create_user(
            email="vendor_rma@example.com",
            username="vendor_rma",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="RMA Store",
            description="Test",
            is_approved=True,
        )
        self.category = Category.objects.create(
            name="Sealed Goods",
            slug="sealed",
            description="",
            is_sealed=True,
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name="Sealed Item",
            description="Test",
            price=Decimal("10.00"),
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

        self.order = Order.objects.create(
            customer=self.customer,
            delivery_address=self.address,
            subtotal_amount=Decimal("20.00"),
            discount_amount=Decimal("0.00"),
            total_amount=Decimal("20.00"),
            status=Order.Status.DELIVERED,
            delivered_at=timezone.now(),
        )
        self.order_item = OrderItem.objects.create(
            order=self.order,
            product=self.product,
            vendor=self.vendor,
            quantity=2,
            price=Decimal("10.00"),
        )

        ReturnPolicy.objects.create(
            name="Default sealed policy",
            category=self.category,
            return_window_days=7,
            sealed_return_window_days=3,
            sealed_requires_unopened=True,
            allow_return=True,
            allow_replace=True,
        )

    def test_create_return_requires_unopened_for_sealed_items(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/returns/",
            data={
                "order_id": self.order.id,
                "request_type": "RETURN",
                "reason": "DEFECTIVE",
                "items": [
                    {"order_item_id": self.order_item.id, "quantity": 1, "condition": "OPENED"}
                ],
                "refund_method_preference": "WALLET",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 400, resp.data)

    def test_create_return_and_wallet_refund(self):
        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/returns/",
            data={
                "order_id": self.order.id,
                "request_type": "RETURN",
                "reason": "DEFECTIVE",
                "items": [{"order_item_id": self.order_item.id, "quantity": 1, "condition": "UNOPENED"}],
                "refund_method_preference": "WALLET",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        rr_id = resp.data["returns"][0]["id"]

        # Vendor marks received then refunds to wallet.
        self.client.force_authenticate(user=self.vendor_user)
        approve = self.client.post(f"/api/vendors/returns/{rr_id}/approve/", data={}, format="json")
        self.assertEqual(approve.status_code, 200, approve.data)
        recv = self.client.post(f"/api/vendors/returns/{rr_id}/received/", data={}, format="json")
        self.assertEqual(recv.status_code, 200, recv.data)

        refund = self.client.post(
            f"/api/vendors/returns/{rr_id}/refund/",
            data={"method": "WALLET"},
            format="json",
        )
        self.assertIn(refund.status_code, [200, 202], refund.data)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.wallet_balance, Decimal("10.00"))

    def test_return_window_expired(self):
        self.order.delivered_at = timezone.now() - timedelta(days=10)
        self.order.save(update_fields=["delivered_at"])

        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/returns/",
            data={
                "order_id": self.order.id,
                "request_type": "RETURN",
                "reason": "OTHER",
                "items": [{"order_item_id": self.order_item.id, "quantity": 1, "condition": "UNOPENED"}],
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 400, resp.data)

    def test_escalate_overdue(self):
        rr = ReturnRequest.objects.create(
            order=self.order,
            customer=self.customer,
            vendor=self.vendor,
            request_type=ReturnRequest.RequestType.RETURN,
            reason=ReturnRequest.Reason.OTHER,
            vendor_response_due_at=timezone.now() - timedelta(hours=1),
        )
        ReturnItem.objects.create(return_request=rr, order_item=self.order_item, quantity=1)

        updated = escalate_overdue_returns()
        self.assertEqual(updated, 1)
        rr.refresh_from_db()
        self.assertEqual(rr.status, ReturnRequest.Status.ESCALATED)
