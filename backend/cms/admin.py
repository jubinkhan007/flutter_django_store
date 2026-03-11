from django.contrib import admin
from unfold.admin import ModelAdmin

from .cache_utils import invalidate_cms_cache
from .html_utils import sanitize_html
from .models import Banner, FAQ, Page, SiteSetting


class CmsCacheInvalidationAdmin(ModelAdmin):
    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        invalidate_cms_cache()

    def delete_model(self, request, obj):
        super().delete_model(request, obj)
        invalidate_cms_cache()

    def delete_queryset(self, request, queryset):
        super().delete_queryset(request, queryset)
        invalidate_cms_cache()


@admin.register(SiteSetting)
class SiteSettingAdmin(CmsCacheInvalidationAdmin):
    list_display = ('key', 'group', 'setting_type', 'is_public', 'updated_at')
    list_filter = ('group', 'setting_type', 'is_public')
    search_fields = ('key', 'value')


@admin.register(Page)
class PageAdmin(CmsCacheInvalidationAdmin):
    list_display = ('title', 'slug', 'page_type', 'is_active', 'updated_at')
    list_filter = ('page_type', 'is_active')
    search_fields = ('title', 'slug', 'meta_title')
    prepopulated_fields = {'slug': ('title',)}

    def save_model(self, request, obj, form, change):
        obj.content = sanitize_html(obj.content)
        super().save_model(request, obj, form, change)


@admin.register(Banner)
class BannerAdmin(CmsCacheInvalidationAdmin):
    list_display = (
        'title',
        'position',
        'platform',
        'target_type',
        'display_order',
        'is_active',
        'updated_at',
    )
    list_filter = ('position', 'platform', 'target_type', 'is_active')
    search_fields = ('title', 'subtitle', 'target_value')
    ordering = ('position', 'display_order')


@admin.register(FAQ)
class FAQAdmin(CmsCacheInvalidationAdmin):
    list_display = ('question', 'category', 'display_order', 'is_active', 'updated_at')
    list_filter = ('category', 'is_active')
    search_fields = ('question', 'answer')
    ordering = ('category', 'display_order')

