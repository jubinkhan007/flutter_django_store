from __future__ import annotations

from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from orders.models import Order, OrderItem
from products.models import Category, Product
from vendors.models import Vendor


class ReturnPolicy(models.Model):
    """
    Return eligibility rules. Priority (most specific wins):
      product > (vendor+category) > vendor > category > global
    """

    name = models.CharField(max_length=100)
    vendor = models.ForeignKey(Vendor, null=True, blank=True, on_delete=models.CASCADE, related_name='return_policies')
    category = models.ForeignKey(Category, null=True, blank=True, on_delete=models.CASCADE, related_name='return_policies')
    product = models.ForeignKey(Product, null=True, blank=True, on_delete=models.CASCADE, related_name='return_policies')

    return_window_days = models.PositiveIntegerField(default=7)
    sealed_return_window_days = models.PositiveIntegerField(null=True, blank=True)
    allow_return = models.BooleanField(default=True)
    allow_replace = models.BooleanField(default=True)
    sealed_requires_unopened = models.BooleanField(default=True)

    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        if self.product_id:
            product = self.product
            if self.vendor_id and product and self.vendor_id != product.vendor_id:
                raise ValidationError({'vendor': 'Vendor must match the selected product.'})
            if self.category_id and product and self.category_id != product.category_id:
                raise ValidationError({'category': 'Category must match the selected product.'})

        if self.sealed_return_window_days is not None and self.sealed_return_window_days > self.return_window_days:
            raise ValidationError('sealed_return_window_days cannot exceed return_window_days.')

        if self.return_window_days <= 0:
            raise ValidationError('return_window_days must be > 0.')

    def __str__(self):
        parts = [self.name]
        if self.product_id:
            parts.append(f'product={self.product_id}')
        if self.vendor_id:
            parts.append(f'vendor={self.vendor_id}')
        if self.category_id:
            parts.append(f'category={self.category_id}')
        return ' / '.join(parts)


class ReturnRequest(models.Model):
    class RequestType(models.TextChoices):
        RETURN = 'RETURN', 'Return'
        REPLACE = 'REPLACE', 'Replace'

    class Status(models.TextChoices):
        SUBMITTED = 'SUBMITTED', 'Submitted'
        VENDOR_APPROVED = 'VENDOR_APPROVED', 'Vendor Approved'
        VENDOR_REJECTED = 'VENDOR_REJECTED', 'Vendor Rejected'
        PICKUP_SCHEDULED = 'PICKUP_SCHEDULED', 'Pickup Scheduled'
        DROPOFF_REQUESTED = 'DROPOFF_REQUESTED', 'Drop-off Requested'
        RECEIVED = 'RECEIVED', 'Received'
        REFUND_PENDING = 'REFUND_PENDING', 'Refund Pending'
        REFUNDED = 'REFUNDED', 'Refunded'
        ESCALATED = 'ESCALATED', 'Escalated'
        CLOSED = 'CLOSED', 'Closed'
        CANCELED = 'CANCELED', 'Canceled'

    class Reason(models.TextChoices):
        DEFECTIVE = 'DEFECTIVE', 'Defective'
        WRONG_ITEM = 'WRONG_ITEM', 'Wrong Item'
        NOT_AS_DESCRIBED = 'NOT_AS_DESCRIBED', 'Not as described'
        DAMAGED = 'DAMAGED', 'Damaged in transit'
        CHANGED_MIND = 'CHANGED_MIND', 'Changed my mind'
        OTHER = 'OTHER', 'Other'

    class Fulfillment(models.TextChoices):
        PICKUP = 'PICKUP', 'Pickup'
        DROPOFF = 'DROPOFF', 'Drop-off'

    class RefundMethod(models.TextChoices):
        ORIGINAL = 'ORIGINAL', 'Original Method'
        WALLET = 'WALLET', 'Wallet Credit'

    class ItemCondition(models.TextChoices):
        UNOPENED = 'UNOPENED', 'Unopened'
        OPENED = 'OPENED', 'Opened'
        USED = 'USED', 'Used'

    rma_number = models.CharField(max_length=40, unique=True, blank=True)
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='return_requests')
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='return_requests')
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='return_requests')

    request_type = models.CharField(max_length=20, choices=RequestType.choices)
    status = models.CharField(max_length=30, choices=Status.choices, default=Status.SUBMITTED)

    reason = models.CharField(max_length=30, choices=Reason.choices)
    reason_details = models.TextField(blank=True)

    fulfillment = models.CharField(max_length=20, choices=Fulfillment.choices, default=Fulfillment.PICKUP)
    pickup_window_start = models.DateTimeField(null=True, blank=True)
    pickup_window_end = models.DateTimeField(null=True, blank=True)
    dropoff_instructions = models.TextField(blank=True)

    refund_method_preference = models.CharField(
        max_length=20,
        choices=RefundMethod.choices,
        default=RefundMethod.ORIGINAL,
    )

    vendor_response_due_at = models.DateTimeField(null=True, blank=True)
    escalated_at = models.DateTimeField(null=True, blank=True)

    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_at = models.DateTimeField(null=True, blank=True)
    received_at = models.DateTimeField(null=True, blank=True)

    vendor_note = models.TextField(blank=True)
    customer_note = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if not self.rma_number:
            # temp placeholder to get an ID on first save
            self.rma_number = f"RMA_{timezone.now().strftime('%Y%m%d%H%M%S')}_{timezone.now().microsecond}"
        super().save(*args, **kwargs)

    def __str__(self):
        return self.rma_number


class ReturnItem(models.Model):
    return_request = models.ForeignKey(ReturnRequest, on_delete=models.CASCADE, related_name='items')
    order_item = models.ForeignKey(OrderItem, on_delete=models.CASCADE, related_name='return_items')
    quantity = models.PositiveIntegerField(default=1)
    condition = models.CharField(
        max_length=20,
        choices=ReturnRequest.ItemCondition.choices,
        default=ReturnRequest.ItemCondition.UNOPENED,
    )

    def clean(self):
        if self.quantity <= 0:
            raise ValidationError({'quantity': 'Quantity must be > 0.'})
        if self.order_item_id and self.quantity > self.order_item.quantity:
            raise ValidationError({'quantity': 'Cannot return more than purchased quantity.'})

    def __str__(self):
        return f'{self.quantity} x item#{self.order_item_id}'


class ReturnImage(models.Model):
    return_request = models.ForeignKey(ReturnRequest, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='returns/')
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    uploaded_at = models.DateTimeField(auto_now_add=True)


class Refund(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        PROCESSING = 'PROCESSING', 'Processing'
        COMPLETED = 'COMPLETED', 'Completed'
        FAILED = 'FAILED', 'Failed'

    return_request = models.ForeignKey(ReturnRequest, on_delete=models.CASCADE, related_name='refunds')
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='refunds')
    amount = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'))
    method = models.CharField(max_length=20, choices=ReturnRequest.RefundMethod.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)

    # External processor tracking (e.g., SSLCommerz)
    provider = models.CharField(max_length=30, blank=True, default='')
    provider_ref_id = models.CharField(max_length=80, blank=True, default='')
    provider_trans_id = models.CharField(max_length=30, blank=True, default='')

    processed_at = models.DateTimeField(null=True, blank=True)
    reference = models.CharField(max_length=255, blank=True)
    failure_reason = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
