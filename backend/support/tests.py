from __future__ import annotations

from decimal import Decimal

from django.utils import timezone
from rest_framework.test import APITestCase

from orders.models import Order, OrderItem, SubOrder
from products.models import Category, Product
from returns.models import ReturnItem, ReturnRequest
from users.models import Address, User
from vendors.models import Vendor

from .models import Ticket


class SupportTicketAccessTest(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            email='admin_support@example.com',
            username='admin_support',
            password='Str0ngPassw0rd!',
            type=User.Types.ADMIN,
        )
        self.customer = User.objects.create_user(
            email='customer_support@example.com',
            username='customer_support',
            password='Str0ngPassw0rd!',
            type=User.Types.CUSTOMER,
        )

        self.vendor_user_1 = User.objects.create_user(
            email='vendor1_support@example.com',
            username='vendor1_support',
            password='Str0ngPassw0rd!',
            type=User.Types.VENDOR,
        )
        self.vendor_1 = Vendor.objects.create(
            user=self.vendor_user_1,
            store_name='Vendor One',
            description='',
            is_approved=True,
        )

        self.vendor_user_2 = User.objects.create_user(
            email='vendor2_support@example.com',
            username='vendor2_support',
            password='Str0ngPassw0rd!',
            type=User.Types.VENDOR,
        )
        self.vendor_2 = Vendor.objects.create(
            user=self.vendor_user_2,
            store_name='Vendor Two',
            description='',
            is_approved=True,
        )

        cat = Category.objects.create(name='Cat', slug='cat', description='')
        product = Product.objects.create(
            vendor=self.vendor_1,
            category=cat,
            name='Item',
            description='',
            price=Decimal('10.00'),
            stock_quantity=10,
            is_available=True,
        )

        address = Address.objects.create(
            user=self.customer,
            label='Home',
            phone_number='01700000000',
            address_line='123 Main St',
            area='Area',
            city='Dhaka',
            is_default=True,
        )

        self.order = Order.objects.create(
            customer=self.customer,
            delivery_address=address,
            subtotal_amount=Decimal('10.00'),
            discount_amount=Decimal('0.00'),
            total_amount=Decimal('10.00'),
            status=Order.Status.DELIVERED,
            delivered_at=timezone.now(),
            payment_method=Order.PaymentMethod.COD,
            payment_status=Order.PaymentStatus.UNPAID,
        )
        self.sub_order = SubOrder.objects.create(order=self.order, vendor=self.vendor_1, status=Order.Status.DELIVERED)
        self.order_item = OrderItem.objects.create(
            sub_order=self.sub_order,
            product=product,
            quantity=1,
            product_title=product.name,
            variant_name='',
            sku='',
            unit_price=product.price,
            image_url='',
        )

        self.rr = ReturnRequest.objects.create(
            order=self.order,
            customer=self.customer,
            vendor=self.vendor_1,
            request_type=ReturnRequest.RequestType.RETURN,
            status=ReturnRequest.Status.ESCALATED,
            reason=ReturnRequest.Reason.OTHER,
            vendor_response_due_at=timezone.now(),
        )
        ReturnItem.objects.create(return_request=self.rr, order_item=self.order_item, quantity=1)

        # Create a ticket linked to vendor_1.
        self.ticket = Ticket.objects.create(
            subject='Test',
            order=self.order,
            sub_order=self.sub_order,
            return_request=self.rr,
            vendor=self.vendor_1,
            customer=self.customer,
        )
        # Force ticket_number generation
        self.ticket.refresh_from_db()

    def test_closed_ticket_rejects_non_admin_messages(self):
        self.ticket.status = Ticket.Status.CLOSED
        self.ticket.save(update_fields=['status'])

        self.client.force_authenticate(user=self.customer)
        resp = self.client.post(
            f'/api/support/tickets/{self.ticket.id}/messages/',
            data={'text': 'hello'},
            format='json',
        )
        self.assertEqual(resp.status_code, 400, resp.data)

        self.client.force_authenticate(user=self.admin)
        resp2 = self.client.post(
            f'/api/support/tickets/{self.ticket.id}/messages/',
            data={'text': 'internal'},
            format='json',
        )
        self.assertEqual(resp2.status_code, 201, resp2.data)

    def test_vendor_cannot_access_other_vendor_ticket(self):
        # Vendor2 should not see or access vendor1-linked ticket
        self.client.force_authenticate(user=self.vendor_user_2)

        list_resp = self.client.get('/api/support/tickets/')
        self.assertEqual(list_resp.status_code, 200)
        self.assertEqual(len(list_resp.data), 0)

        detail_resp = self.client.get(f'/api/support/tickets/{self.ticket.id}/')
        self.assertEqual(detail_resp.status_code, 404)

