from django.contrib import admin

from .models import DeviceToken, Notification, NotificationPreference


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'platform', 'is_active', 'last_seen_at', 'updated_at')
    list_filter = ('platform', 'is_active')
    search_fields = ('user__email', 'token', 'device_id')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'type',
        'category',
        'is_read',
        'delivery_status',
        'created_at',
    )
    list_filter = ('type', 'category', 'is_read', 'delivery_status')
    search_fields = ('user__email', 'title', 'body', 'deeplink')


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(admin.ModelAdmin):
    list_display = ('user', 'order_updates', 'payout_updates', 'promotions', 'updated_at')
    search_fields = ('user__email',)

