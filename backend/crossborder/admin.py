from django.contrib import admin

from .models import CrossBorderCostConfig, CrossBorderOrderRequest, CrossBorderProduct


@admin.register(CrossBorderProduct)
class CrossBorderProductAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "title",
        "origin_marketplace",
        "currency",
        "base_price_foreign",
        "is_active",
        "priority",
        "created_at",
    )
    list_filter = ("is_active", "origin_marketplace", "currency")
    search_fields = ("title", "source_url", "supplier_sku")
    ordering = ("-priority", "-created_at")


@admin.register(CrossBorderCostConfig)
class CrossBorderCostConfigAdmin(admin.ModelAdmin):
    list_display = (
        "shipping_method",
        "rate_per_kg",
        "service_fee_type",
        "service_fee_value",
        "customs_rate_percentage",
        "fx_rate_bdt",
        "is_active",
        "updated_at",
    )
    list_filter = ("shipping_method", "is_active", "service_fee_type")
    ordering = ("shipping_method",)


@admin.register(CrossBorderOrderRequest)
class CrossBorderOrderRequestAdmin(admin.ModelAdmin):
    list_display = ("id", "customer", "request_type", "status", "shipping_method", "created_at")
    list_filter = ("status", "request_type", "shipping_method", "marketplace")
    search_fields = ("id", "source_url", "supplier_order_id", "tracking_number")
    ordering = ("-created_at",)

