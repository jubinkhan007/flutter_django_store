from django.contrib import admin
from .models import User

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('email', 'username', 'type', 'is_active', 'date_joined')
    list_filter = ('type', 'is_active')
    search_fields = ('email', 'username')
