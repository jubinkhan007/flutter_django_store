from django.contrib import admin

from .models import UserEvent


@admin.register(UserEvent)
class UserEventAdmin(admin.ModelAdmin):
    list_display = ('id', 'event_type', 'source', 'product_id', 'user_id', 'session_id', 'created_at')
    list_filter = ('event_type', 'source', 'created_at')
    search_fields = ('session_id', 'user__email', 'product__name')

# Register your models here.
