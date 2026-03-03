import uuid

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from products.models import Category, Product
from vendors.models import Vendor

from .models import UserEvent
from .tasks import purge_old_user_events


User = get_user_model()


class UserEventLoggingTest(APITestCase):
    def setUp(self):
        super().setUp()
        self.customer = User.objects.create_user(
            email='cust@example.com',
            username='cust',
            password='pass12345',
            type='CUSTOMER',
        )
        vendor_user = User.objects.create_user(
            email='vendor@example.com',
            username='vendor',
            password='pass12345',
            type='VENDOR',
        )
        self.vendor = Vendor.objects.create(user=vendor_user, store_name='Test Store')
        self.category = Category.objects.create(name='Electronics', slug='electronics')
        self.product = Product.objects.create(
            vendor=self.vendor,
            category=self.category,
            name='Phone',
            description='A phone',
            price='10.00',
            stock_quantity=5,
            is_available=True,
        )

    def test_guest_event_logs_with_session_id_and_no_user(self):
        session_id = str(uuid.uuid4())
        resp = self.client.post(
            '/api/analytics/events/',
            {
                'events': [
                    {
                        'event_type': 'VIEW',
                        'source': 'PDP',
                        'product_id': self.product.id,
                        'session_id': session_id,
                        'metadata': {'position': 1},
                    }
                ]
            },
            format='json',
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(UserEvent.objects.count(), 1)
        ev = UserEvent.objects.first()
        self.assertIsNone(ev.user_id)
        self.assertEqual(str(ev.session_id), session_id)
        self.assertEqual(ev.product_id, self.product.id)

    def test_opt_out_user_skips_logging(self):
        self.customer.personalization_enabled = False
        self.customer.save(update_fields=['personalization_enabled'])

        login = self.client.post(
            '/api/auth/login/',
            {'email': 'cust@example.com', 'password': 'pass12345'},
            format='json',
        )
        self.assertEqual(login.status_code, 200, login.data)
        token = login.data['access']

        session_id = str(uuid.uuid4())
        resp = self.client.post(
            '/api/analytics/events/',
            {
                'events': [
                    {
                        'event_type': 'CLICK',
                        'source': 'HOME',
                        'product_id': self.product.id,
                        'session_id': session_id,
                    }
                ]
            },
            format='json',
            HTTP_AUTHORIZATION=f'Bearer {token}',
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data.get('skipped'), True)
        self.assertEqual(UserEvent.objects.count(), 0)


class UserEventRetentionTest(APITestCase):
    def test_purge_old_events_respects_retention_days(self):
        # Create one old event and one recent event.
        ev_old = UserEvent.objects.create(
            event_type='VIEW',
            source='HOME',
            session_id=uuid.uuid4(),
        )
        ev_recent = UserEvent.objects.create(
            event_type='VIEW',
            source='HOME',
            session_id=uuid.uuid4(),
        )

        from django.utils import timezone
        from datetime import timedelta
        ev_old.created_at = timezone.now() - timedelta(days=10)
        ev_old.save(update_fields=['created_at'])

        from django.test import override_settings
        with override_settings(ANALYTICS_RETENTION_DAYS=5):
            result = purge_old_user_events()

        self.assertGreaterEqual(result.get('deleted', 0), 1)
        remaining = list(UserEvent.objects.values_list('id', flat=True))
        self.assertIn(ev_recent.id, remaining)
        self.assertNotIn(ev_old.id, remaining)
