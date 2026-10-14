from django.contrib import admin
from django.urls import reverse
from django.utils.html import format_html
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
    list_display = (
        'id',
        'customer',
        'total_amount_display',
        'wallet_applied_display',
        'payable_amount_display',
        'show_status',
        'show_payment',
        'invoice_link',
        'created_at',
    )
    list_filter = ('status', 'payment_status', 'payment_method')
    list_select_related = ('customer', 'delivery_address')
    search_fields = ('id', 'customer__email', 'customer__username', 'transaction_id')
    date_hierarchy = 'created_at'
    inlines = [SubOrderInline]
    readonly_fields = ('idempotency_key', 'invoice_link', 'payable_amount_display')

    fieldsets = (
        ('Order Information', {
            'fields': ('customer', 'delivery_address', 'coupon', 'status', 'idempotency_key'),
            'classes': ['tab'],
        }),
        ('Financials & Payment', {
            'fields': (
                'subtotal_amount',
                'discount_amount',
                'wallet_amount_applied',
                'total_amount',
                'payable_amount_display',
                'payment_method',
                'payment_status',
                'invoice_link',
            ),
            'classes': ['tab'],
        }),
        ('Payment Gateway References', {
            'fields': ('transaction_id', 'val_id', 'bank_tran_id'),
            'classes': ['tab'],
        }),
        ('Timestamps', {
            'fields': ('created_at', 'delivered_at', 'updated_at'),
            'classes': ['tab'],
        }),
    )

    readonly_fields = (
        'idempotency_key',
        'invoice_link',
        'payable_amount_display',
        'created_at',
        'updated_at',
    )

    @display(description='Total')
    def total_amount_display(self, obj):
        return f"৳{obj.total_amount:,.2f}"

    @display(description='Wallet Used')
    def wallet_applied_display(self, obj):
        if not obj.wallet_amount_applied or obj.wallet_amount_applied <= 0:
            return "—"
        return f"-৳{obj.wallet_amount_applied:,.2f}"

    @display(description='Net Payable')
    def payable_amount_display(self, obj):
        return f"৳{obj.payable_amount:,.2f}"

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

    @display(description='Tax Invoice')
    def invoice_link(self, obj):
        url = reverse('order-invoice-pdf', kwargs={'pk': obj.pk})
        return format_html(
            '<a href="{}" target="_blank" class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold rounded bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300 dark:border-emerald-800">'
            '<span class="material-symbols-outlined text-[14px]">picture_as_pdf</span> PDF</a>',
            url,
        )
