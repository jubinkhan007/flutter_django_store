from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch

from django.utils import timezone
from rest_framework.test import APITestCase

from orders.models import Order, OrderItem
from products.models import Category, Product
from returns.models import Refund, ReturnItem, ReturnPolicy, ReturnRequest
from returns.services import escalate_overdue_returns
from returns.sslcommerz_refund_client import SSLCommerzRefundInitResult, SSLCommerzRefundStatusResult
from returns.tasks import poll_sslcommerz_refund_status
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

        # Create an order via the real API to ensure SubOrder/OrderItem snapshots exist.
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
        assert resp.status_code == 201, resp.data
        self.order = Order.objects.get(id=resp.data["id"])
        self.order.status = Order.Status.DELIVERED
        self.order.delivered_at = timezone.now()
        self.order.save(update_fields=["status", "delivered_at"])

        self.order_item = (
            OrderItem.objects.select_related("product", "sub_order", "sub_order__vendor", "product__category")
            .filter(sub_order__order=self.order)
            .first()
        )
        assert self.order_item is not None

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

    def test_original_method_refund_via_sslcommerz_polling(self):
        # Make the order an ONLINE paid order with a stored bank_tran_id.
        self.order.payment_method = Order.PaymentMethod.ONLINE
        self.order.payment_status = Order.PaymentStatus.PAID
        self.order.bank_tran_id = "1709162345070ANJdZV8LyI4cMw"
        self.order.save(update_fields=["payment_method", "payment_status", "bank_tran_id"])

        # Customer creates return.
        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/returns/",
            data={
                "order_id": self.order.id,
                "request_type": "RETURN",
                "reason": "DEFECTIVE",
                "items": [{"order_item_id": self.order_item.id, "quantity": 1, "condition": "UNOPENED"}],
                "refund_method_preference": "ORIGINAL",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        rr_id = resp.data["returns"][0]["id"]

        # Vendor approves + marks received.
        self.client.force_authenticate(user=self.vendor_user)
        approve = self.client.post(f"/api/vendors/returns/{rr_id}/approve/", data={}, format="json")
        self.assertEqual(approve.status_code, 200, approve.data)
        recv = self.client.post(f"/api/vendors/returns/{rr_id}/received/", data={}, format="json")
        self.assertEqual(recv.status_code, 200, recv.data)

        with patch(
            "returns.views.SSLCommerzRefundClient.initiate_refund",
            return_value=SSLCommerzRefundInitResult(
                api_connect="DONE",
                bank_tran_id=self.order.bank_tran_id,
                trans_id="SSLCZ_TEST_59bd635981a94",
                refund_ref_id="59bd63fea5455",
                status="success",
                error_reason="",
            ),
        ), patch("returns.tasks.SSLCommerzRefundClient.query_refund_status") as mock_query, patch(
            "returns.tasks.FinancialService.debit_for_refund"
        ) as mock_debit:
            mock_query.return_value = SSLCommerzRefundStatusResult(
                api_connect="DONE",
                bank_tran_id=self.order.bank_tran_id,
                tran_id="SSLCZ_TEST_59bd635981a94",
                refund_ref_id="59bd63fea5455",
                initiated_on="2017-09-16 23:48:46",
                refunded_on="2017-09-17 08:53:51",
                status="refunded",
                error_reason="",
            )

            refund_resp = self.client.post(
                f"/api/vendors/returns/{rr_id}/refund/",
                data={"method": "ORIGINAL"},
                format="json",
            )
            self.assertEqual(refund_resp.status_code, 202, refund_resp.data)

            rr = ReturnRequest.objects.get(id=rr_id)
            refund = rr.refunds.get(method=ReturnRequest.RefundMethod.ORIGINAL)
            self.assertEqual(refund.status, Refund.Status.PROCESSING)
            self.assertEqual(refund.provider, "SSLCOMMERZ")
            self.assertTrue(refund.provider_ref_id)
            self.assertTrue(refund.provider_trans_id)

            # Poll completes the refund.
            completed = poll_sslcommerz_refund_status(refund.id)
            self.assertEqual(completed, 1)

            rr.refresh_from_db()
            refund.refresh_from_db()
            self.assertEqual(rr.status, ReturnRequest.Status.REFUNDED)
            self.assertEqual(refund.status, Refund.Status.COMPLETED)
            self.assertIsNotNone(refund.processed_at)
            mock_debit.assert_called_once()

    def test_original_method_refund_requires_bank_tran_id(self):
        self.order.payment_method = Order.PaymentMethod.ONLINE
        self.order.payment_status = Order.PaymentStatus.PAID
        self.order.bank_tran_id = None
        self.order.save(update_fields=["payment_method", "payment_status", "bank_tran_id"])

        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            "/api/returns/",
            data={
                "order_id": self.order.id,
                "request_type": "RETURN",
                "reason": "DEFECTIVE",
                "items": [{"order_item_id": self.order_item.id, "quantity": 1, "condition": "UNOPENED"}],
                "refund_method_preference": "ORIGINAL",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        rr_id = resp.data["returns"][0]["id"]

        self.client.force_authenticate(user=self.vendor_user)
        approve = self.client.post(f"/api/vendors/returns/{rr_id}/approve/", data={}, format="json")
        self.assertEqual(approve.status_code, 200, approve.data)
        recv = self.client.post(f"/api/vendors/returns/{rr_id}/received/", data={}, format="json")
        self.assertEqual(recv.status_code, 200, recv.data)

        refund_resp = self.client.post(
            f"/api/vendors/returns/{rr_id}/refund/",
            data={"method": "ORIGINAL"},
            format="json",
        )
        self.assertEqual(refund_resp.status_code, 400, refund_resp.data)

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
