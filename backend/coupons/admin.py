from django.contrib import admin

from .models import Coupon


@admin.register(Coupon)
class CouponAdmin(admin.ModelAdmin):
    list_display = ('code', 'scope', 'vendor', 'discount_type', 'discount_value', 'is_active', 'created_at')
    list_filter = ('scope', 'discount_type', 'is_active')
    search_fields = ('code', 'vendor__store_name', 'vendor__user__email')
    filter_horizontal = ('applicable_products', 'applicable_categories')

