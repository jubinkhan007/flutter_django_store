from django.contrib import admin

from .models import Collection, CollectionItem, ProductAffinity


class CollectionItemInline(admin.TabularInline):
    model = CollectionItem
    extra = 0
    raw_id_fields = ('product',)


@admin.register(Collection)
class CollectionAdmin(admin.ModelAdmin):
    list_display = ('slug', 'title', 'is_active', 'starts_at', 'ends_at', 'priority')
    list_filter = ('is_active',)
    search_fields = ('slug', 'title')
    inlines = [CollectionItemInline]


@admin.register(ProductAffinity)
class ProductAffinityAdmin(admin.ModelAdmin):
    list_display = ('from_product', 'to_product', 'score', 'last_updated_at')
    search_fields = ('from_product__name', 'to_product__name')
    list_filter = ('last_updated_at',)

# Register your models here.
