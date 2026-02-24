from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models

from products.models import Product, Category
from vendors.models import Vendor


class Coupon(models.Model):
    class Scope(models.TextChoices):
        GLOBAL = 'GLOBAL', 'Global (All Shops)'
        VENDOR = 'VENDOR', 'Vendor (Single Shop)'

    class DiscountType(models.TextChoices):
        PERCENT = 'PERCENT', 'Percent'
        FIXED = 'FIXED', 'Fixed Amount'

    code = models.CharField(max_length=32, unique=True)
    scope = models.CharField(max_length=20, choices=Scope.choices, default=Scope.GLOBAL)
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, null=True, blank=True, related_name='coupons')

    discount_type = models.CharField(max_length=20, choices=DiscountType.choices)
    discount_value = models.DecimalField(max_digits=10, decimal_places=2)

    min_order_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    applicable_products = models.ManyToManyField(Product, blank=True, related_name='coupons')
    applicable_categories = models.ManyToManyField(Category, blank=True, related_name='coupons')

    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        self.code = (self.code or '').strip().upper()

        if self.scope == self.Scope.VENDOR and not self.vendor_id:
            raise ValidationError({'vendor': 'Vendor coupons must have a vendor.'})
        if self.scope == self.Scope.GLOBAL and self.vendor_id:
            raise ValidationError({'vendor': 'Global coupons cannot be tied to a vendor.'})

        if self.discount_value is None:
            raise ValidationError({'discount_value': 'Discount value is required.'})

        if self.discount_type == self.DiscountType.PERCENT:
            if self.discount_value <= 0 or self.discount_value > Decimal('100'):
                raise ValidationError({'discount_value': 'Percent discount must be between 0 and 100.'})
        else:
            if self.discount_value <= 0:
                raise ValidationError({'discount_value': 'Fixed discount must be greater than 0.'})

        if self.min_order_amount is not None and self.min_order_amount < 0:
            raise ValidationError({'min_order_amount': 'Minimum order amount cannot be negative.'})

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.code} ({self.scope})'

