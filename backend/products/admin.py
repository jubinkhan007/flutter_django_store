from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline

from .models import Category, Product, ProductVariant, ScheduledPriceRule


class ProductVariantInline(TabularInline):
    model = ProductVariant
    extra = 0
    show_all_pages = True
    max_num = 0
    readonly_fields = ('sku', 'stock_on_hand', 'reserved_stock', 'effective_price')
    tab = True


class ScheduledPriceRuleInline(TabularInline):
    model = ScheduledPriceRule
    extra = 0
    show_all_pages = True
    max_num = 0
    tab = True


@admin.register(Category)
class CategoryAdmin(ModelAdmin):
    list_display = ('name', 'slug')
    prepopulated_fields = {'slug': ('name',)}
    search_fields = ('name',)


@admin.register(Product)
class ProductAdmin(ModelAdmin):
    list_display = ('name', 'vendor', 'category', 'price', 'stock_quantity', 'is_available')
    list_filter = ('is_available', 'category')
    list_select_related = ('vendor', 'category')
    search_fields = ('name', 'sku', 'vendor__store_name')
    date_hierarchy = 'created_at'
    inlines = [ProductVariantInline, ScheduledPriceRuleInline]

    fieldsets = (
        ('Basic Info', {
            'fields': ('name', 'slug', 'vendor', 'category', 'description'),
            'classes': ['tab'],
        }),
        ('Pricing & Stock', {
            'fields': ('price', 'compare_at_price', 'stock_quantity', 'sku', 'is_available'),
            'classes': ['tab'],
        }),
        ('Media', {
            'fields': ('image',),
            'classes': ['tab'],
        }),
    )
