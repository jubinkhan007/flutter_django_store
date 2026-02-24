from django.contrib import admin
from .models import Order, SubOrder, OrderItem

class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ('product', 'variant', 'quantity', 'unit_price', 'product_title', 'sku')

class SubOrderInline(admin.TabularInline):
    model = SubOrder
    extra = 0
    readonly_fields = ('vendor', 'status', 'accepted_at', 'packed_at', 'shipped_at', 'delivered_at', 'canceled_at')

@admin.register(SubOrder)
class SubOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'order', 'vendor', 'status', 'created_at')
    list_filter = ('status', 'vendor')
    inlines = [OrderItemInline]

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'customer', 'total_amount', 'status', 'created_at')
    list_filter = ('status',)
    inlines = [SubOrderInline]
