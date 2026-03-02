from __future__ import annotations

from datetime import timedelta

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from orders.models import Order, SubOrder
from returns.models import ReturnRequest
from vendors.models import Vendor


class Ticket(models.Model):
    class Category(models.TextChoices):
        ORDER = 'ORDER', 'Order'
        PAYMENT = 'PAYMENT', 'Payment'
        ACCOUNT = 'ACCOUNT', 'Account'
        TECH = 'TECH', 'Tech'
        OTHER = 'OTHER', 'Other'

    class Status(models.TextChoices):
        OPEN = 'OPEN', 'Open'
        PENDING_CUSTOMER = 'PENDING_CUSTOMER', 'Pending Customer'
        PENDING_VENDOR = 'PENDING_VENDOR', 'Pending Vendor'
        PENDING_SUPPORT = 'PENDING_SUPPORT', 'Pending Support'
        RESOLVED = 'RESOLVED', 'Resolved'
        CLOSED = 'CLOSED', 'Closed'

    ticket_number = models.CharField(max_length=20, unique=True, blank=True, default='')
    subject = models.CharField(max_length=255, blank=True, default='')
    category = models.CharField(max_length=30, choices=Category.choices, default=Category.OTHER)

    # Context
    order = models.ForeignKey(Order, null=True, blank=True, on_delete=models.SET_NULL, related_name='support_tickets')
    sub_order = models.ForeignKey(SubOrder, null=True, blank=True, on_delete=models.SET_NULL, related_name='support_tickets')
    return_request = models.ForeignKey(
        ReturnRequest, null=True, blank=True, on_delete=models.SET_NULL, related_name='support_tickets'
    )
    vendor = models.ForeignKey(Vendor, null=True, blank=True, on_delete=models.SET_NULL, related_name='support_tickets')

    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='support_tickets'
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='assigned_tickets'
    )

    status = models.CharField(max_length=30, choices=Status.choices, default=Status.OPEN)

    # SLA / lifecycle timestamps
    first_response_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    last_activity_at = models.DateTimeField(default=timezone.now)

    is_overdue_first_response = models.BooleanField(default=False)
    is_overdue_resolution = models.BooleanField(default=False)

    # Snapshot for dispute/escalation context (items, amounts, images, etc.)
    context_snapshot = models.JSONField(default=dict, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-last_activity_at', '-created_at']
        indexes = [
            models.Index(fields=['customer', 'status', '-last_activity_at']),
            models.Index(fields=['vendor', 'status', '-last_activity_at']),
        ]

    def clean(self):
        if self.vendor_id and self.sub_order_id and self.sub_order and self.vendor_id != self.sub_order.vendor_id:
            raise ValidationError({'vendor': 'Vendor must match the sub_order vendor.'})
        if self.vendor_id and self.return_request_id and self.return_request and self.vendor_id != self.return_request.vendor_id:
            raise ValidationError({'vendor': 'Vendor must match the return_request vendor.'})

    def save(self, *args, **kwargs):
        creating = self.pk is None
        if creating and not self.last_activity_at:
            self.last_activity_at = timezone.now()
        super().save(*args, **kwargs)

        if not self.ticket_number:
            year = (self.created_at or timezone.now()).year
            self.ticket_number = f"TCK-{year}-{self.id:06d}"
            super().save(update_fields=['ticket_number'])

    def can_reopen(self) -> bool:
        if self.status != self.Status.RESOLVED:
            return False
        if not self.resolved_at:
            return False
        return timezone.now() <= self.resolved_at + timedelta(days=7)

    def __str__(self) -> str:
        return self.ticket_number or f"Ticket#{self.id}"


class TicketMessage(models.Model):
    class Kind(models.TextChoices):
        TEXT = 'TEXT', 'Text'
        IMAGE = 'IMAGE', 'Image'
        SYSTEM_EVENT = 'SYSTEM_EVENT', 'System Event'

    ticket = models.ForeignKey(Ticket, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.TEXT)
    text = models.TextField(blank=True, default='')

    is_internal_note = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at', 'id']

    def __str__(self) -> str:
        return f'{self.ticket_id} {self.kind}'


class TicketAttachment(models.Model):
    message = models.ForeignKey(TicketMessage, on_delete=models.CASCADE, related_name='attachments')
    file = models.FileField(upload_to='support/')
    file_type = models.CharField(max_length=50, blank=True, default='')
    size = models.PositiveIntegerField(default=0)
    storage_key = models.CharField(max_length=255, blank=True, default='')

    uploaded_at = models.DateTimeField(auto_now_add=True)
