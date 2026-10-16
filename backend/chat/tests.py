from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from products.models import Category, Product
from vendors.models import Vendor
from chat.models import Conversation, ChatMessage

User = get_user_model()


class ChatTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Customer user
        self.customer = User.objects.create_user(
            username='customer_jane',
            email='jane@example.com',
            password='Password123!',
            first_name='Jane',
            last_name='Doe',
        )

        # Vendor user & store
        self.vendor_user = User.objects.create_user(
            username='vendor_bob',
            email='bob@example.com',
            password='Password123!',
            first_name='Bob',
            last_name='Vendor',
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name='ElectroTech Store',
            is_approved=True,
            is_live=True,
        )

        # Another random user (unauthorized third party)
        self.other_user = User.objects.create_user(
            username='other_alice',
            email='alice@example.com',
            password='Password123!',
        )

        # Sample Product
        self.category = Category.objects.create(name='Electronics', slug='electronics')
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Wireless Headphones',
            description='Noise cancelling headphones',
            price=2500.00,
            stock_quantity=10,
        )

    def test_customer_start_conversation_and_send_messages(self):
        self.client.force_authenticate(user=self.customer)

        # 1. Start conversation with product context & initial message
        start_payload = {
            'vendor_id': self.vendor.id,
            'product_id': self.product.id,
            'message': 'Hello, is this product available in black?',
        }
        res = self.client.post('/api/chat/conversations/start/', start_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        conv_id = res.data['id']
        self.assertEqual(res.data['vendor_name'], 'ElectroTech Store')
        self.assertEqual(res.data['product']['id'], self.product.id)
        self.assertEqual(len(res.data['messages']), 1)
        self.assertEqual(res.data['messages'][0]['text'], 'Hello, is this product available in black?')

        # 2. Check conversation in DB
        conv = Conversation.objects.get(id=conv_id)
        self.assertEqual(conv.customer, self.customer)
        self.assertEqual(conv.vendor, self.vendor)
        self.assertEqual(conv.vendor_unread_count, 1)
        self.assertEqual(conv.customer_unread_count, 0)

        # 3. Customer sends second message
        send_res = self.client.post(
            f'/api/chat/conversations/{conv_id}/messages/',
            {'text': 'Also, does it have warranty?'},
            format='json',
        )
        self.assertEqual(send_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(send_res.data['text'], 'Also, does it have warranty?')

        conv.refresh_from_db()
        self.assertEqual(conv.vendor_unread_count, 2)
        self.assertEqual(conv.customer_unread_count, 0)
        self.assertEqual(conv.last_message_preview, 'Also, does it have warranty?')

    def test_vendor_view_and_reply_flow(self):
        # Create conversation with customer message
        conv = Conversation.objects.create(
            customer=self.customer,
            vendor=self.vendor,
            product=self.product,
            last_message_preview='Can I get a discount?',
            vendor_unread_count=1,
        )
        msg1 = ChatMessage.objects.create(
            conversation=conv,
            sender=self.customer,
            sender_type=ChatMessage.SenderType.CUSTOMER,
            text='Can I get a discount?',
        )

        # Vendor logs in
        self.client.force_authenticate(user=self.vendor_user)

        # 1. Vendor lists conversations
        list_res = self.client.get('/api/chat/conversations/')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_res.data), 1)
        self.assertEqual(list_res.data[0]['customer_id'], self.customer.id)
        self.assertEqual(list_res.data[0]['unread_count'], 1)

        # 2. Vendor gets total unread count
        unread_res = self.client.get('/api/chat/unread-count/')
        self.assertEqual(unread_res.status_code, status.HTTP_200_OK)
        self.assertEqual(unread_res.data['unread_count'], 1)

        # 3. Vendor opens conversation (automatically marks as read)
        detail_res = self.client.get(f'/api/chat/conversations/{conv.id}/')
        self.assertEqual(detail_res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(detail_res.data['messages']), 1)

        conv.refresh_from_db()
        self.assertEqual(conv.vendor_unread_count, 0)
        msg1.refresh_from_db()
        self.assertTrue(msg1.is_read)

        # 4. Vendor sends reply message
        reply_res = self.client.post(
            f'/api/chat/conversations/{conv.id}/messages/',
            {'text': 'Yes! Use coupon TECH10 for 10% off.'},
            format='json',
        )
        self.assertEqual(reply_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(reply_res.data['sender_type'], 'VENDOR')

        conv.refresh_from_db()
        self.assertEqual(conv.customer_unread_count, 1)
        self.assertEqual(conv.vendor_unread_count, 0)

        # 5. Customer polls with after_id
        self.client.force_authenticate(user=self.customer)
        poll_res = self.client.get(f'/api/chat/conversations/{conv.id}/?after_id={msg1.id}')
        self.assertEqual(poll_res.status_code, status.HTTP_200_OK)
        # Only the vendor's reply is returned because its ID > msg1.id
        self.assertEqual(len(poll_res.data['messages']), 1)
        self.assertEqual(poll_res.data['messages'][0]['text'], 'Yes! Use coupon TECH10 for 10% off.')

    def test_unauthorized_access_prevented(self):
        conv = Conversation.objects.create(
            customer=self.customer,
            vendor=self.vendor,
        )

        # Unauthorized user tries to view conversation
        self.client.force_authenticate(user=self.other_user)
        res = self.client.get(f'/api/chat/conversations/{conv.id}/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Unauthorized user tries to send message
        send_res = self.client.post(
            f'/api/chat/conversations/{conv.id}/messages/',
            {'text': 'Hacking into conversation'},
            format='json',
        )
        self.assertEqual(send_res.status_code, status.HTTP_403_FORBIDDEN)

    def test_vendor_cannot_chat_with_own_store(self):
        self.client.force_authenticate(user=self.vendor_user)
        res = self.client.post(
            '/api/chat/conversations/start/',
            {'vendor_id': self.vendor.id, 'message': 'Talking to myself'},
            format='json',
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
