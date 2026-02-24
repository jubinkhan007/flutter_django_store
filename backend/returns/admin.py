from django.contrib import admin

from .models import Refund, ReturnImage, ReturnItem, ReturnPolicy, ReturnRequest


@admin.register(ReturnPolicy)
class ReturnPolicyAdmin(admin.ModelAdmin):
    list_display = ('name', 'vendor', 'category', 'product', 'return_window_days', 'allow_return', 'allow_replace', 'is_active')
    list_filter = ('is_active', 'allow_return', 'allow_replace')
    search_fields = ('name', 'vendor__store_name', 'product__name', 'category__name')


class ReturnItemInline(admin.TabularInline):
    model = ReturnItem
    extra = 0


class ReturnImageInline(admin.TabularInline):
    model = ReturnImage
    extra = 0


@admin.register(ReturnRequest)
class ReturnRequestAdmin(admin.ModelAdmin):
    list_display = ('rma_number', 'order', 'customer', 'vendor', 'request_type', 'status', 'created_at')
    list_filter = ('status', 'request_type', 'reason', 'fulfillment')
    search_fields = ('rma_number', 'customer__email', 'vendor__store_name')
    inlines = [ReturnItemInline, ReturnImageInline]


@admin.register(Refund)
class RefundAdmin(admin.ModelAdmin):
    list_display = ('id', 'return_request', 'amount', 'method', 'status', 'processed_at', 'created_at')
    list_filter = ('status', 'method')

