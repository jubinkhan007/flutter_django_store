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
    delivered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order #{self.id} by {self.customer}"

class SubOrder(models.Model):
    """
    SubOrder groups order items by vendor.
    """
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='sub_orders')
    vendor = models.ForeignKey(Vendor, on_delete=models.PROTECT, related_name='sub_orders')
    status = models.CharField(max_length=20, choices=Order.Status.choices, default=Order.Status.PENDING)
    
    # SLA Timers
    accepted_at = models.DateTimeField(null=True, blank=True)
    packed_at = models.DateTimeField(null=True, blank=True)
    shipped_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    canceled_at = models.DateTimeField(null=True, blank=True)
    ship_by_date = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"SubOrder {self.id} - Vendor: {self.vendor.store_name} - Order: {self.order.id}"

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
