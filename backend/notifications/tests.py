from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from .models import DeviceToken, Notification, NotificationPreference
from .tasks import dispatch_notification_task


User = get_user_model()


class NotificationsApiTest(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='notify@example.com',
            username='notify',
            password='Str0ngPassw0rd!',
            type=User.Types.CUSTOMER,
        )
        self.client.force_authenticate(user=self.user)

    def test_unread_count_and_mark_read(self):
        Notification.objects.create(
            user=self.user,
            title='A',
            body='',
            type=Notification.Type.ORDER_PLACED,
            category=Notification.Category.TRANSACTIONAL,
            deeplink='app://orders/1',
            push_enabled=False,
        )
        notif2 = Notification.objects.create(
            user=self.user,
            title='B',
            body='',
            type=Notification.Type.ORDER_SHIPPED,
            category=Notification.Category.TRANSACTIONAL,
            deeplink='app://orders/1?sub_id=2',
            push_enabled=False,
        )

        resp = self.client.get('/api/notifications/unread-count/')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['unread'], 2)

        read = self.client.post(f'/api/notifications/{notif2.id}/read/')
        self.assertEqual(read.status_code, 200)

        resp2 = self.client.get('/api/notifications/unread-count/')
        self.assertEqual(resp2.data['unread'], 1)

        all_read = self.client.post('/api/notifications/mark-all-read/')
        self.assertEqual(all_read.status_code, 200)
        resp3 = self.client.get('/api/notifications/unread-count/')
        self.assertEqual(resp3.data['unread'], 0)

    def test_promo_preference_blocks_push(self):
        DeviceToken.objects.create(
            user=self.user,
            token='tok1',
            platform=DeviceToken.Platform.ANDROID,
            is_active=True,
        )
        pref, _ = NotificationPreference.objects.get_or_create(user=self.user)
        pref.promotions = False
        pref.save(update_fields=['promotions'])

        notif = Notification.objects.create(
            user=self.user,
            title='Promo',
            body='',
            type=Notification.Type.PROMOTION,
            category=Notification.Category.PROMOTION,
            deeplink='app://promos/1',
            push_enabled=True,
            inbox_visible=False,
        )

        dispatch_notification_task.run(str(notif.id))
        notif.refresh_from_db()
        self.assertEqual(notif.delivery_status, Notification.DeliveryStatus.SKIPPED)

    def test_transactional_push_marks_sent_when_send_ok(self):
        DeviceToken.objects.create(
            user=self.user,
            token='tok2',
            platform=DeviceToken.Platform.ANDROID,
            is_active=True,
        )
        pref, _ = NotificationPreference.objects.get_or_create(user=self.user)
        pref.order_updates = True
        pref.save(update_fields=['order_updates'])

        notif = Notification.objects.create(
            user=self.user,
            title='Order',
            body='Placed',
            type=Notification.Type.ORDER_PLACED,
            category=Notification.Category.TRANSACTIONAL,
            deeplink='app://orders/123',
            push_enabled=True,
        )

        from unittest.mock import patch

        with patch('notifications.tasks._send_fcm', return_value=(True, {'results': [{}]})):
            dispatch_notification_task.run(str(notif.id))

        notif.refresh_from_db()
        self.assertEqual(notif.delivery_status, Notification.DeliveryStatus.SENT)
