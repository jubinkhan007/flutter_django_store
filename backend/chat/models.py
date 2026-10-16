from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils import timezone

from products.models import Product
from orders.models import Order
from vendors.models import Vendor


class Conversation(models.Model):
    """
    Direct 1-on-1 chat thread between a customer and a marketplace vendor.
    Can be initiated with optional product inquiry context or post-order support context.
    """
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='customer_conversations',
    )
    vendor = models.ForeignKey(
        Vendor,
        on_delete=models.CASCADE,
        related_name='vendor_conversations',
    )
    # Context (can be updated when customer asks about a different product or order)
    product = models.ForeignKey(
        Product,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='chat_conversations',
    )
    order = models.ForeignKey(
        Order,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='chat_conversations',
    )

    last_message_at = models.DateTimeField(default=timezone.now, db_index=True)
    last_message_preview = models.CharField(max_length=255, blank=True, default='')
    customer_unread_count = models.PositiveIntegerField(default=0)
    vendor_unread_count = models.PositiveIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-last_message_at']
        unique_together = ('customer', 'vendor')
        indexes = [
            models.Index(fields=['customer', '-last_message_at']),
            models.Index(fields=['vendor', '-last_message_at']),
        ]

    def __str__(self) -> str:
        return f"{self.customer} <-> {self.vendor.store_name}"

    def mark_as_read_for(self, user):
        """
        Marks unread messages as read depending on whether user is customer or vendor.
        """
        is_vendor = (
            hasattr(user, 'vendor_profile') and user.vendor_profile == self.vendor
        )
        if is_vendor:
            self.messages.filter(is_read=False).exclude(sender=user).update(is_read=True)
            self.vendor_unread_count = 0
            self.save(update_fields=['vendor_unread_count'])
        else:
            self.messages.filter(is_read=False).exclude(sender=user).update(is_read=True)
            self.customer_unread_count = 0
            self.save(update_fields=['customer_unread_count'])


class ChatMessage(models.Model):
    class SenderType(models.TextChoices):
        CUSTOMER = 'CUSTOMER', 'Customer'
        VENDOR = 'VENDOR', 'Vendor'

    class MessageType(models.TextChoices):
        TEXT = 'TEXT', 'Text'
        IMAGE = 'IMAGE', 'Image'
        PRODUCT = 'PRODUCT', 'Product'
        ORDER = 'ORDER', 'Order'

    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages',
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_chat_messages',
    )
    sender_type = models.CharField(
        max_length=10,
        choices=SenderType.choices,
        default=SenderType.CUSTOMER,
    )
    message_type = models.CharField(
        max_length=20,
        choices=MessageType.choices,
        default=MessageType.TEXT,
    )
    text = models.TextField(blank=True, default='')
    image = models.ImageField(upload_to='chat_images/', null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['created_at', 'id']
        indexes = [
            models.Index(fields=['conversation', 'created_at']),
            models.Index(fields=['conversation', 'is_read']),
        ]

    def __str__(self) -> str:
        return f"Msg {self.id} by {self.sender} ({self.sender_type}) in Conv {self.conversation_id}"
