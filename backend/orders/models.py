from django.db import models
from django.conf import settings
from products.models import Product, ProductVariant
from vendors.models import Vendor
from users.models import Address

class Order(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        PAID = 'PAID', 'Paid'
        SHIPPED = 'SHIPPED', 'Shipped'
        DELIVERED = 'DELIVERED', 'Delivered'
        CANCELED = 'CANCELED', 'Canceled'

    class PaymentMethod(models.TextChoices):
        ONLINE = 'ONLINE', 'Online'
        COD = 'COD', 'Cash on Delivery'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'UNPAID', 'Unpaid'
        PAID = 'PAID', 'Paid'
        REFUNDED = 'REFUNDED', 'Refunded'

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='orders')
    delivery_address = models.ForeignKey(Address, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    coupon = models.ForeignKey('coupons.Coupon', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    subtotal_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    payment_method = models.CharField(max_length=20, choices=PaymentMethod.choices, default=PaymentMethod.ONLINE)
    payment_status = models.CharField(max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID)
    transaction_id = models.CharField(max_length=255, blank=True, null=True, help_text="System generated trxn_id for SSLCommerz")
    val_id = models.CharField(max_length=255, blank=True, null=True, help_text="Validation ID from SSLCommerz (needed for refunds)")
    bank_tran_id = models.CharField(
        max_length=80,
        blank=True,
        null=True,
        help_text="Bank-side transaction ID from SSLCommerz (required for refund API).",
    )
    idempotency_key = models.CharField(max_length=64, unique=True, null=True, blank=True, help_text="Client-generated UUID to prevent duplicate orders")
    delivered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order #{self.id} by {self.customer}"

class SubOrder(models.Model):
    """
    SubOrder groups order items by vendor.
    """
    class ProvisionStatus(models.TextChoices):
        NOT_STARTED = 'NOT_STARTED', 'Not started'
        REQUESTED = 'REQUESTED', 'Requested'
        CREATED = 'CREATED', 'Created'
        FAILED = 'FAILED', 'Failed'

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='sub_orders')
    vendor = models.ForeignKey(Vendor, on_delete=models.PROTECT, related_name='sub_orders')
    status = models.CharField(max_length=20, choices=Order.Status.choices, default=Order.Status.PENDING)

    # Courier / Tracking
    courier_code = models.CharField(max_length=50, blank=True, help_text="e.g. 'pathao', 'redx'")
    courier_name = models.CharField(max_length=100, blank=True, help_text="e.g. 'Pathao Delivers'")
    tracking_number = models.CharField(max_length=100, blank=True)
    tracking_url = models.URLField(blank=True)
    provision_status = models.CharField(
        max_length=20,
        choices=ProvisionStatus.choices,
        default=ProvisionStatus.NOT_STARTED,
    )
    courier_reference_id = models.CharField(max_length=255, blank=True, default='')
    last_error = models.TextField(blank=True, default='')
    provision_request = models.JSONField(default=dict, blank=True)

    # SLA Timers
    accepted_at = models.DateTimeField(null=True, blank=True)
    packed_at = models.DateTimeField(null=True, blank=True)
    shipped_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    canceled_at = models.DateTimeField(null=True, blank=True)
    ship_by_date = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Valid forward transitions
    _TRANSITIONS = {
        Order.Status.PENDING:  [Order.Status.SHIPPED, Order.Status.CANCELED],
        Order.Status.PAID:     [Order.Status.SHIPPED, Order.Status.CANCELED],
        Order.Status.SHIPPED:  [Order.Status.DELIVERED, Order.Status.CANCELED],
    }

    def advance_status(self, new_status):
        """State machine: validate then advance. Raises ValueError on illegal moves."""
        from django.utils import timezone
        terminal = {Order.Status.DELIVERED, Order.Status.CANCELED}
        if self.status in terminal:
            raise ValueError(f"Sub-order #{self.id} is already {self.status} and cannot be mutated.")
        allowed = self._TRANSITIONS.get(self.status, [])
        if new_status not in allowed:
            raise ValueError(
                f"Cannot transition SubOrder #{self.id} from '{self.status}' to '{new_status}'. "
                f"Allowed next states: {allowed}"
            )
        now = timezone.now()
        self.status = new_status
        if new_status == Order.Status.SHIPPED:
            self.shipped_at = now
        elif new_status == Order.Status.DELIVERED:
            self.delivered_at = now
        elif new_status == Order.Status.CANCELED:
            self.canceled_at = now
        self.save()

    def __str__(self):
        return f"SubOrder {self.id} - Vendor: {self.vendor.store_name} - Order: {self.order.id}"


class ShipmentEvent(models.Model):
    """Ordered log of tracking events for a SubOrder."""

    class EventStatus(models.TextChoices):
        PROCESSING = 'PROCESSING', 'Processing'
        PACKED = 'PACKED', 'Packed'
        PICKED_UP = 'PICKED_UP', 'Picked Up'
        IN_TRANSIT = 'IN_TRANSIT', 'In Transit'
        OUT_FOR_DELIVERY = 'OUT_FOR_DELIVERY', 'Out for Delivery'
        DELIVERED = 'DELIVERED', 'Delivered'
        CANCELLED = 'CANCELLED', 'Cancelled'
        RETURNED = 'RETURNED', 'Returned'

    class Source(models.TextChoices):
        VENDOR = 'VENDOR', 'Vendor'
        WEBHOOK = 'WEBHOOK', 'Webhook'
        POLLING = 'POLLING', 'Polling'
        SYSTEM = 'SYSTEM', 'System'

    sub_order = models.ForeignKey(SubOrder, on_delete=models.CASCADE, related_name='events')
    status = models.CharField(max_length=30, choices=EventStatus.choices)
    location = models.CharField(max_length=255, blank=True)
    timestamp = models.DateTimeField()
    description = models.TextField(blank=True)
    sequence = models.IntegerField(default=0)
    source = models.CharField(max_length=20, choices=Source.choices, default=Source.VENDOR)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='shipment_events'
    )
    external_event_id = models.CharField(
        max_length=255, blank=True, null=True,
        help_text="Idempotency key for courier webhooks"
    )

    class Meta:
        ordering = ['sequence', 'timestamp']
        constraints = [
            models.UniqueConstraint(
                fields=['sub_order', 'external_event_id'],
                name='uniq_shipmentevent_suborder_external_event_id',
                condition=models.Q(external_event_id__isnull=False),
            )
        ]

    def __str__(self):
        return f"[{self.status}] SubOrder #{self.sub_order_id} @ {self.timestamp}"

class OrderItem(models.Model):
    sub_order = models.ForeignKey(SubOrder, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True)
    variant = models.ForeignKey(ProductVariant, on_delete=models.SET_NULL, null=True, blank=True)
    
    quantity = models.PositiveIntegerField(default=1)
    
    # Snapshot fields (critical for historical accuracy)
    product_title = models.CharField(max_length=255, blank=True)
    variant_name = models.CharField(max_length=255, blank=True)
    sku = models.CharField(max_length=100, blank=True)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2) # Price per unit at purchase
    tax = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    discount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    image_url = models.URLField(max_length=500, blank=True)

    def __str__(self):
        return f"{self.quantity} x {self.product_title}"

    @property
    def total_price(self):
        return (self.unit_price * self.quantity) + self.tax - self.discount
