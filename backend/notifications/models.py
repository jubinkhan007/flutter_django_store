from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class DeviceToken(models.Model):
    class Platform(models.TextChoices):
        ANDROID = 'ANDROID', 'Android'
        IOS = 'IOS', 'iOS'
        WEB = 'WEB', 'Web'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='device_tokens',
    )
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=20, choices=Platform.choices)
    device_id = models.CharField(max_length=100, blank=True, default='')
    app_version = models.CharField(max_length=50, blank=True, default='')
    is_active = models.BooleanField(default=True)
    last_seen_at = models.DateTimeField(default=timezone.now)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f'{self.user_id} {self.platform} {self.token[:10]}...'


class NotificationPreference(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notification_preferences',
    )

    order_updates = models.BooleanField(default=True)
    payout_updates = models.BooleanField(default=True)
    promotions = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f'Preferences({self.user_id})'


class Notification(models.Model):
    class Category(models.TextChoices):
        TRANSACTIONAL = 'TRANSACTIONAL', 'Transactional'
        PROMOTION = 'PROMOTION', 'Promotion'

    class Type(models.TextChoices):
        ORDER_PLACED = 'ORDER_PLACED', 'Order Placed'
        ORDER_SHIPPED = 'ORDER_SHIPPED', 'Order Shipped'
        REFUND_PROCESSED = 'REFUND_PROCESSED', 'Refund Processed'
        NEW_SUBORDER = 'NEW_SUBORDER', 'New SubOrder'
        PAYOUT_APPROVED = 'PAYOUT_APPROVED', 'Payout Approved'
        PAYOUT_REQUESTED = 'PAYOUT_REQUESTED', 'Payout Requested'
        PROMOTION = 'PROMOTION', 'Promotion'

    class DeliveryStatus(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        SENT = 'SENT', 'Sent'
        FAILED = 'FAILED', 'Failed'
        SKIPPED = 'SKIPPED', 'Skipped'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
    )

    title = models.CharField(max_length=255)
    body = models.TextField(blank=True)
    type = models.CharField(max_length=50, choices=Type.choices)
    category = models.CharField(max_length=20, choices=Category.choices)

    data = models.JSONField(default=dict, blank=True)
    deeplink = models.CharField(max_length=255, blank=True, default='')

    inbox_visible = models.BooleanField(default=True)
    push_enabled = models.BooleanField(default=True)

    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    delivery_status = models.CharField(
        max_length=20,
        choices=DeliveryStatus.choices,
        default=DeliveryStatus.PENDING,
    )
    delivered_at = models.DateTimeField(null=True, blank=True)
    delivery_error = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at', '-id']
        indexes = [
            models.Index(fields=['user', 'is_read', '-created_at']),
            models.Index(fields=['user', 'type', '-created_at']),
        ]

    def mark_read(self) -> None:
        if self.is_read:
            return
        self.is_read = True
        self.read_at = timezone.now()
        self.save(update_fields=['is_read', 'read_at', 'updated_at'])

    def __str__(self) -> str:
        return f'{self.user_id} {self.type} {self.title}'

