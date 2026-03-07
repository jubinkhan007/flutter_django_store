import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class CrossBorderProduct(models.Model):
    """Curated catalog item sourced from an international marketplace."""

    class Marketplace(models.TextChoices):
        AMAZON = 'AMAZON', 'Amazon'
        ALIEXPRESS = 'ALIEXPRESS', 'AliExpress'
        ALIBABA = 'ALIBABA', 'Alibaba'
        SHOP_1688 = '1688', '1688'
        OTHER = 'OTHER', 'Other'

    title = models.CharField(max_length=512)
    description = models.TextField(blank=True)
    images = models.JSONField(default=list, blank=True, help_text='List of image URLs')
    origin_marketplace = models.CharField(max_length=20, choices=Marketplace.choices)
    source_url = models.URLField(max_length=1000)
    supplier_sku = models.CharField(max_length=255, blank=True)

    base_price_foreign = models.DecimalField(max_digits=14, decimal_places=2)
    currency = models.CharField(max_length=3, default='USD', help_text='ISO 4217 currency code')
    estimated_weight_kg = models.DecimalField(max_digits=8, decimal_places=3, default=0.5)

    category = models.ForeignKey(
        'products.Category',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='cb_products',
    )

    is_active = models.BooleanField(default=True)
    priority = models.PositiveIntegerField(default=0, help_text='Higher = shown first')
    policy_summary = models.TextField(blank=True, help_text='Return/warranty limitations')

    lead_time_days_min = models.PositiveIntegerField(default=7)
    lead_time_days_max = models.PositiveIntegerField(default=21)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-priority', '-created_at']

    def __str__(self):
        return f'[CB] {self.title[:60]} ({self.origin_marketplace})'

    @property
    def primary_image(self):
        if self.images:
            return self.images[0]
        return ''


class CrossBorderCostConfig(models.Model):
    """Admin-tunable pricing parameters for cross-border shipping."""

    class ShippingMethod(models.TextChoices):
        AIR = 'AIR', 'Air Freight'
        SEA = 'SEA', 'Sea Freight'

    class ServiceFeeType(models.TextChoices):
        FIXED = 'FIXED', 'Fixed Amount (BDT)'
        PERCENTAGE = 'PERCENTAGE', 'Percentage of item price'

    shipping_method = models.CharField(max_length=10, choices=ShippingMethod.choices, unique=True)
    rate_per_kg = models.DecimalField(max_digits=10, decimal_places=2, help_text='BDT per kg')
    service_fee_type = models.CharField(max_length=20, choices=ServiceFeeType.choices, default=ServiceFeeType.PERCENTAGE)
    service_fee_value = models.DecimalField(max_digits=10, decimal_places=2, default=10, help_text='Amount or %')
    customs_rate_percentage = models.DecimalField(
        max_digits=5, decimal_places=2, default=25,
        help_text='Informational estimate only; customer pays on delivery',
    )
    fx_rate_bdt = models.DecimalField(max_digits=10, decimal_places=4, default=110, help_text='1 USD = X BDT')
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'CB Cost Config ({self.shipping_method})'


class CrossBorderOrderRequest(models.Model):
    """Core purchase-on-behalf record linking to a SubOrder."""

    class RequestType(models.TextChoices):
        CATALOG_ITEM = 'CATALOG_ITEM', 'Catalog Item'
        LINK_PURCHASE = 'LINK_PURCHASE', 'Buy by Link'

    class Marketplace(models.TextChoices):
        AMAZON = 'AMAZON', 'Amazon'
        ALIEXPRESS = 'ALIEXPRESS', 'AliExpress'
        ALIBABA = 'ALIBABA', 'Alibaba'
        SHOP_1688 = '1688', '1688'
        OTHER = 'OTHER', 'Other'

    class ShippingMethod(models.TextChoices):
        AIR = 'AIR', 'Air Freight'
        SEA = 'SEA', 'Sea Freight'

    class Status(models.TextChoices):
        REQUESTED = 'REQUESTED', 'Requested'
        QUOTED = 'QUOTED', 'Quoted'
        PAYMENT_RECEIVED = 'PAYMENT_RECEIVED', 'Payment Received'
        ORDERED = 'ORDERED', 'Ordered from Supplier'
        SHIPPED_INTL = 'SHIPPED_INTL', 'Shipped Internationally'
        IN_TRANSIT = 'IN_TRANSIT', 'In Transit (Local)'
        OUT_FOR_DELIVERY = 'OUT_FOR_DELIVERY', 'Out for Delivery'
        DELIVERED = 'DELIVERED', 'Delivered'
        CANCELLED = 'CANCELLED', 'Cancelled'
        REFUND_IN_PROGRESS = 'REFUND_IN_PROGRESS', 'Refund in Progress'
        CUSTOMS_HELD = 'CUSTOMS_HELD', 'Held at Customs'

    sub_order = models.OneToOneField(
        'orders.SubOrder',
        on_delete=models.CASCADE,
        related_name='cb_request',
        null=True,
        blank=True,
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='cb_requests',
    )

    request_type = models.CharField(max_length=20, choices=RequestType.choices)
    crossborder_product = models.ForeignKey(
        CrossBorderProduct,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_requests',
    )
    source_url = models.URLField(max_length=1000, blank=True)
    marketplace = models.CharField(max_length=20, choices=Marketplace.choices, default=Marketplace.OTHER)
    variant_notes = models.TextField(blank=True, help_text='Color/size/spec the customer wants')
    quantity = models.PositiveIntegerField(default=1)

    delivery_mode = models.CharField(max_length=30, default='DIRECT_TO_CUSTOMER', editable=False)
    customer_address_snapshot = models.JSONField(help_text='Exact address at checkout')
    shipping_method = models.CharField(max_length=10, choices=ShippingMethod.choices, default=ShippingMethod.AIR)

    # Quote
    quote_id = models.UUIDField(default=uuid.uuid4, unique=True)
    quote_expires_at = models.DateTimeField(null=True, blank=True)
    estimated_cost_breakdown = models.JSONField(
        default=dict,
        blank=True,
        help_text='{item_price_bdt, intl_shipping_bdt, service_fee_bdt, customs_est_bdt, total_bdt}',
    )
    customs_policy_acknowledged = models.BooleanField(default=False)
    expected_delivery_days_min = models.PositiveIntegerField(default=7)
    expected_delivery_days_max = models.PositiveIntegerField(default=21)

    # Ops fields
    status = models.CharField(max_length=30, choices=Status.choices, default=Status.REQUESTED)
    supplier_order_id = models.CharField(max_length=255, blank=True)
    carrier_name = models.CharField(max_length=100, blank=True)
    tracking_number = models.CharField(max_length=255, blank=True)
    tracking_url = models.URLField(blank=True)
    assigned_ops_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_cb_requests',
    )

    # Cost finalization
    realized_item_cost_bdt = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    realized_shipping_bdt = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    ops_notes = models.TextField(blank=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    quoted_at = models.DateTimeField(null=True, blank=True)
    ordered_at = models.DateTimeField(null=True, blank=True)
    shipped_intl_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'CBRequest #{self.id} ({self.status}) by {self.customer_id}'

    @property
    def is_quote_valid(self):
        return self.quote_expires_at and timezone.now() < self.quote_expires_at

    @property
    def title(self):
        if self.crossborder_product:
            return self.crossborder_product.title
        return self.source_url or 'Custom Link Request'
