from django.contrib import admin
from unfold.admin import ModelAdmin
from unfold.decorators import display

from .models import CrossBorderCostConfig, CrossBorderOrderRequest, CrossBorderProduct


@admin.register(CrossBorderProduct)
class CrossBorderProductAdmin(ModelAdmin):
    list_display = (
        'id', 'title_short', 'origin_marketplace', 'currency',
        'base_price_foreign', 'show_active', 'priority', 'created_at',
    )
    list_filter = ('is_active', 'origin_marketplace', 'currency')
    search_fields = ('title', 'source_url', 'supplier_sku')
    ordering = ('-priority', '-created_at')
    date_hierarchy = 'created_at'

    fieldsets = (
        ('Product Info', {
            'fields': ('title', 'description', 'category', 'origin_marketplace', 'source_url', 'supplier_sku'),
            'classes': ['tab'],
        }),
        ('Pricing & Shipping', {
            'fields': ('base_price_foreign', 'currency', 'estimated_weight_kg', 'lead_time_days_min', 'lead_time_days_max'),
            'classes': ['tab'],
        }),
        ('Display', {
            'fields': ('images', 'is_active', 'priority', 'policy_summary'),
            'classes': ['tab'],
        }),
    )

    def title_short(self, obj):
        return obj.title[:60] + '…' if len(obj.title) > 60 else obj.title
    title_short.short_description = 'Title'

    @display(description='Active', label={True: 'success', False: 'danger'})
    def show_active(self, obj):
        return obj.is_active


@admin.register(CrossBorderCostConfig)
class CrossBorderCostConfigAdmin(ModelAdmin):
    list_display = (
        'shipping_method', 'rate_per_kg', 'service_fee_type',
        'service_fee_value', 'customs_rate_percentage', 'fx_rate_bdt',
        'show_active', 'updated_at',
    )
    list_filter = ('shipping_method', 'is_active', 'service_fee_type')
    ordering = ('shipping_method',)

    @display(description='Active', label={True: 'success', False: 'danger'})
    def show_active(self, obj):
        return obj.is_active


@admin.register(CrossBorderOrderRequest)
class CrossBorderOrderRequestAdmin(ModelAdmin):
    list_display = (
        'id', 'customer', 'request_type', 'show_status',
        'marketplace', 'shipping_method', 'created_at',
    )
    list_filter = ('status', 'request_type', 'shipping_method', 'marketplace')
    list_select_related = ('customer', 'crossborder_product')
    search_fields = ('id', 'source_url', 'supplier_order_id', 'tracking_number')
    ordering = ('-created_at',)
    date_hierarchy = 'created_at'

    fieldsets = (
        ('Request Info', {
            'fields': (
                'customer', 'request_type', 'crossborder_product', 'source_url',
                'marketplace', 'variant_notes', 'quantity',
            ),
            'classes': ['tab'],
        }),
        ('Quote & Cost', {
            'fields': (
                'shipping_method', 'estimated_cost_breakdown',
                'customs_policy_acknowledged',
                'expected_delivery_days_min', 'expected_delivery_days_max',
                'quote_expires_at', 'quoted_at',
            ),
            'classes': ['tab'],
        }),
        ('Ops Milestones', {
            'fields': (
                'status', 'supplier_order_id', 'carrier_name',
                'tracking_number', 'tracking_url', 'assigned_ops_user',
                'ordered_at', 'shipped_intl_at', 'delivered_at',
            ),
            'classes': ['tab'],
        }),
        ('Financial Adjustments', {
            'fields': ('realized_item_cost_bdt', 'realized_shipping_bdt', 'ops_notes'),
            'classes': ['tab'],
        }),
    )

    @display(description='Status', label={
        'REQUESTED': 'warning',
        'QUOTED': 'info',
        'PAYMENT_RECEIVED': 'info',
        'ORDERED': 'info',
        'SHIPPED_INTL': 'info',
        'IN_TRANSIT': 'info',
        'OUT_FOR_DELIVERY': 'info',
        'DELIVERED': 'success',
        'CANCELLED': 'danger',
        'REFUND_IN_PROGRESS': 'warning',
        'CUSTOMS_HELD': 'danger',
    })
    def show_status(self, obj):
        return obj.status
