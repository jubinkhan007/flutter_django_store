from django.contrib import admin

from .models import CourierIntegration, LogisticsArea, LogisticsStore


@admin.register(CourierIntegration)
class CourierIntegrationAdmin(admin.ModelAdmin):
    list_display = ('courier', 'owner_type', 'owner_vendor', 'mode', 'is_enabled', 'updated_at')
    list_filter = ('courier', 'owner_type', 'mode', 'is_enabled')
    search_fields = ('owner_vendor__store_name',)


@admin.register(LogisticsStore)
class LogisticsStoreAdmin(admin.ModelAdmin):
    list_display = ('courier', 'mode', 'name', 'owner_type', 'owner_vendor', 'external_store_id', 'is_active')
    list_filter = ('courier', 'mode', 'owner_type', 'is_active')
    search_fields = ('name', 'external_store_id', 'owner_vendor__store_name')
    filter_horizontal = ('assigned_vendors',)


@admin.register(LogisticsArea)
class LogisticsAreaAdmin(admin.ModelAdmin):
    list_display = ('courier', 'mode', 'kind', 'external_id', 'name', 'parent', 'last_synced_at')
    list_filter = ('courier', 'mode', 'kind')
    search_fields = ('name', 'external_id')

