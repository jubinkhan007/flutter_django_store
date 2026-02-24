from django.db import models
from django.conf import settings
from products.models import Product
from vendors.models import Vendor
from users.models import Address

class Order(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        PAID = 'PAID', 'Paid'
        SHIPPED = 'SHIPPED', 'Shipped'
        DELIVERED = 'DELIVERED', 'Delivered'
        CANCELED = 'CANCELED', 'Canceled'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'UNPAID', 'Unpaid'
        PAID = 'PAID', 'Paid'
        REFUNDED = 'REFUNDED', 'Refunded'

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='orders')
    delivery_address = models.ForeignKey(Address, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    payment_status = models.CharField(max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID)
    transaction_id = models.CharField(max_length=255, blank=True, null=True, help_text="System generated trxn_id for SSLCommerz")
    val_id = models.CharField(max_length=255, blank=True, null=True, help_text="Validation ID from SSLCommerz (needed for refunds)")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order #{self.id} by {self.customer}"

class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True)
    vendor = models.ForeignKey(Vendor, on_delete=models.PROTECT) # Don't delete order history if vendor is deleted
    quantity = models.PositiveIntegerField(default=1)
    price = models.DecimalField(max_digits=10, decimal_places=2) # Price at time of purchase

    def __str__(self):
        return f"{self.quantity} x {self.product.name}"
