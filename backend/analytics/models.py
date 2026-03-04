from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models


class UserEvent(models.Model):
    class EventType(models.TextChoices):
        VIEW = 'VIEW', 'View'
        CLICK = 'CLICK', 'Click'
        ADD_TO_CART = 'ADD_TO_CART', 'Add to cart'
        PURCHASE = 'PURCHASE', 'Purchase'
        IMPRESSION = 'IMPRESSION', 'Impression'

    class Source(models.TextChoices):
        HOME = 'HOME', 'Home'
        SEARCH = 'SEARCH', 'Search'
        PDP = 'PDP', 'Product detail'
        COLLECTION = 'COLLECTION', 'Collection'
        NOTIFICATION = 'NOTIFICATION', 'Notification'
        OTHER = 'OTHER', 'Other'

    event_type = models.CharField(max_length=30, choices=EventType.choices)
    source = models.CharField(max_length=30, choices=Source.choices, default=Source.OTHER)
    is_sponsored = models.BooleanField(default=False)

    product = models.ForeignKey(
        'products.Product',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='user_events',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='user_events',
    )
    session_id = models.UUIDField(default=uuid.uuid4, null=True, blank=True, db_index=True)

    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        indexes = [
            models.Index(fields=['product', 'created_at'], name='ue_product_created_idx'),
            models.Index(fields=['session_id', 'created_at'], name='ue_session_created_idx'),
            models.Index(
                fields=['user', 'created_at'],
                name='ue_user_created_idx',
                condition=models.Q(user__isnull=False),
            ),
        ]

    def __str__(self) -> str:
        who = self.user_id if self.user_id else str(self.session_id)
        return f'{self.event_type} {self.product_id or "-"} by {who}'
