from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from .models import Order, OrderItem, ShipmentEvent, SubOrder


# ── Inlines ──────────────────────────────────────────────────────────────────

class OrderItemInline(TabularInline):
    model = OrderItem
    extra = 0
    show_all_pages = True
    max_num = 0
    readonly_fields = ('product', 'variant', 'quantity', 'unit_price', 'product_title', 'sku')
    tab = True


class SubOrderInline(TabularInline):
    model = SubOrder
    extra = 0
    show_all_pages = True
    max_num = 0
    readonly_fields = (
        'vendor', 'status', 'fulfillment_type',
        'accepted_at', 'packed_at', 'shipped_at', 'delivered_at', 'canceled_at',
    )
    tab = True


class ShipmentEventInline(TabularInline):
    model = ShipmentEvent
    extra = 0
    readonly_fields = ('status', 'location', 'timestamp', 'description', 'source')
    ordering = ('-timestamp',)
    tab = True


# ── SubOrder Admin ───────────────────────────────────────────────────────────

@admin.register(SubOrder)
class SubOrderAdmin(ModelAdmin):
    list_display = ('id', 'order', 'vendor', 'show_status', 'fulfillment_type', 'created_at')
    list_filter = ('status', 'fulfillment_type', 'vendor')
    list_select_related = ('order', 'vendor')
    search_fields = ('id', 'order__id', 'tracking_number')
    date_hierarchy = 'created_at'
    inlines = [OrderItemInline, ShipmentEventInline]

    @display(description='Status', label={
        Order.Status.PENDING: 'warning',
        Order.Status.PAID: 'info',
        Order.Status.SHIPPED: 'info',
        Order.Status.DELIVERED: 'success',
        Order.Status.CANCELED: 'danger',
    })
    def show_status(self, obj):
        return obj.status


# ── Order Admin ──────────────────────────────────────────────────────────────

@admin.register(Order)
class OrderAdmin(ModelAdmin):
    list_display = ('id', 'customer', 'total_amount', 'show_status', 'show_payment', 'created_at')
    list_filter = ('status', 'payment_status', 'payment_method')
    list_select_related = ('customer',)
    search_fields = ('id', 'customer__email', 'customer__username')
    date_hierarchy = 'created_at'
    inlines = [SubOrderInline]
    readonly_fields = ('idempotency_key',)

    fieldsets = (
        ('Order Info', {
            'fields': ('customer', 'status', 'idempotency_key'),
            'classes': ['tab'],
        }),
        ('Financials', {
            'fields': ('subtotal_amount', 'total_amount', 'discount_amount', 'payment_method', 'payment_status'),
            'classes': ['tab'],
        }),
    )

    @display(description='Status', label={
        Order.Status.PENDING: 'warning',
        Order.Status.PAID: 'info',
        Order.Status.SHIPPED: 'info',
        Order.Status.DELIVERED: 'success',
        Order.Status.CANCELED: 'danger',
    })
    def show_status(self, obj):
        return obj.status

    @display(description='Payment', label={
        Order.PaymentStatus.UNPAID: 'danger',
        Order.PaymentStatus.PAID: 'success',
        Order.PaymentStatus.REFUNDED: 'warning',
    })
    def show_payment(self, obj):
        return obj.payment_status
