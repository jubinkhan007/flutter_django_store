from django.contrib import admin
from unfold.admin import ModelAdmin
from unfold.decorators import display, action

from .models import CourierIntegration, LiveDeliveryTracking, LogisticsArea, LogisticsStore


@admin.register(CourierIntegration)
class CourierIntegrationAdmin(ModelAdmin):
    list_display = ('courier', 'owner_type', 'owner_vendor', 'mode', 'is_enabled', 'updated_at')
    list_filter = ('courier', 'owner_type', 'mode', 'is_enabled')
    search_fields = ('owner_vendor__store_name',)


@admin.register(LogisticsStore)
class LogisticsStoreAdmin(ModelAdmin):
    list_display = ('courier', 'mode', 'name', 'owner_type', 'owner_vendor', 'external_store_id', 'is_active')
    list_filter = ('courier', 'mode', 'owner_type', 'is_active')
    search_fields = ('name', 'external_store_id', 'owner_vendor__store_name')
    filter_horizontal = ('assigned_vendors',)


@admin.register(LogisticsArea)
class LogisticsAreaAdmin(ModelAdmin):
    list_display = ('courier', 'mode', 'kind', 'external_id', 'name', 'parent', 'last_synced_at')
    list_filter = ('courier', 'mode', 'kind')
    search_fields = ('name', 'external_id')


@admin.register(LiveDeliveryTracking)
class LiveDeliveryTrackingAdmin(ModelAdmin):
    list_display = (
        'sub_order_link',
        'courier_brand',
        'rider_name',
        'rider_phone',
        'vehicle_number',
        'show_status',
        'eta_display',
        'distance_display',
        'speed_display',
        'last_location_update',
    )
    list_filter = ('status', 'courier_brand', 'vehicle_type')
    search_fields = ('rider_name', 'rider_phone', 'vehicle_number', 'sub_order__id')
    readonly_fields = ('created_at', 'updated_at', 'last_location_update')
    actions = ['advance_simulation_step', 'mark_delivered', 'reset_to_hub']

    @display(description='Sub-Order')
    def sub_order_link(self, obj):
        return f"SubOrder #{obj.sub_order_id} (Order #{obj.sub_order.order_id})"

    @display(
        description='Status',
        label={
            'DISPATCHED': 'info',
            'PICKED_UP': 'info',
            'IN_TRANSIT': 'primary',
            'OUT_FOR_DELIVERY': 'warning',
            'ARRIVING_SOON': 'warning',
            'DELIVERED': 'success',
        }
    )
    def show_status(self, obj):
        return obj.status

    @display(description='ETA')
    def eta_display(self, obj):
        return f"{obj.eta_minutes} mins"

    @display(description='Distance')
    def distance_display(self, obj):
        return f"{obj.distance_km} km"

    @display(description='Speed')
    def speed_display(self, obj):
        return f"{obj.speed_kmh} km/h"

    @action(description='Advance live rider simulation 1 step')
    def advance_simulation_step(self, request, queryset):
        for obj in queryset:
            obj.advance_simulation(steps=1)
        self.message_user(request, f"Advanced {queryset.count()} rider simulations.")

    @action(description='Mark shipment as Delivered')
    def mark_delivered(self, request, queryset):
        for obj in queryset:
            obj.status = LiveDeliveryTracking.DispatchStatus.DELIVERED
            obj.eta_minutes = 0
            from decimal import Decimal
            obj.distance_km = Decimal('0.00')
            obj.speed_kmh = 0.0
            obj.save()
        self.message_user(request, f"Marked {queryset.count()} shipments as Delivered.")

    @action(description='Reset rider to Hub')
    def reset_to_hub(self, request, queryset):
        for obj in queryset:
            obj.current_waypoint_index = 0
            obj.status = LiveDeliveryTracking.DispatchStatus.OUT_FOR_DELIVERY
            obj.current_latitude = obj.origin_latitude
            obj.current_longitude = obj.origin_longitude
            obj.eta_minutes = 18
            from decimal import Decimal
            obj.distance_km = Decimal('3.50')
            obj.speed_kmh = 24.0
            obj.save()
        self.message_user(request, f"Reset {queryset.count()} riders to origin hub.")

