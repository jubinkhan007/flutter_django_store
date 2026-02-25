# ═══════════════════════════════════════════════════════════════════
# PROMOTIONS ADMIN
# Rich Django Admin for managing banners, flash sales, and sections
# ═══════════════════════════════════════════════════════════════════

from django.contrib import admin
from django.utils import timezone
from django.utils.html import format_html
from .models import Banner, FlashSale, FlashSaleProduct, FeaturedSection


# ── Custom Filters ───────────────────────────────────────────────

class ActiveNowFilter(admin.SimpleListFilter):
    """Filter to show only currently active and time-valid promotions."""
    title = 'Live Status'
    parameter_name = 'live_status'

    def lookups(self, request, model_admin):
        return (
            ('active_now', 'Active Now'),
            ('scheduled', 'Scheduled (Future)'),
            ('expired', 'Expired'),
            ('disabled', 'Disabled'),
        )

    def queryset(self, request, queryset):
        now = timezone.now()
        if self.value() == 'active_now':
            return queryset.filter(is_active=True, starts_at__lte=now, ends_at__gte=now)
        if self.value() == 'scheduled':
            return queryset.filter(is_active=True, starts_at__gt=now)
        if self.value() == 'expired':
            return queryset.filter(ends_at__lt=now)
        if self.value() == 'disabled':
            return queryset.filter(is_active=False)
        return queryset


# ── Shared Fieldsets ─────────────────────────────────────────────

SCHEDULING_FIELDSET = ('Scheduling', {
    'fields': ('is_active', 'priority', 'starts_at', 'ends_at'),
    'description': 'Control when and how prominently this item appears.',
})

TARGETING_FIELDSET = ('Targeting', {
    'fields': ('audience', 'platform', 'locale'),
    'classes': ('collapse',),
    'description': 'Optional: narrow who sees this. Leave as "All" for global visibility.',
})


# ═══════════════════════════════════════════════════════════════════
# BANNER ADMIN
# ═══════════════════════════════════════════════════════════════════

@admin.register(Banner)
class BannerAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'image_preview', 'link_type',
        'priority', 'is_active', 'live_badge',
        'starts_at', 'ends_at',
    )
    list_filter = (ActiveNowFilter, 'link_type', 'platform', 'audience')
    list_editable = ('priority', 'is_active')
    search_fields = ('title', 'subtitle')
    ordering = ['-priority', 'starts_at']

    fieldsets = (
        ('Content', {
            'fields': ('title', 'subtitle', 'image'),
            'description': 'Recommended image: 1080×500px, JPEG/WebP, under 500KB.',
        }),
        ('Link', {
            'fields': ('link_type', 'link_value'),
            'description': 'Product ID, Category slug, URL, or search query.',
        }),
        SCHEDULING_FIELDSET,
        TARGETING_FIELDSET,
    )

    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" style="max-height:40px; border-radius:4px;" />',
                obj.image.url,
            )
        return '—'
    image_preview.short_description = 'Preview'

    def live_badge(self, obj):
        if obj.is_live:
            return format_html('<span style="color:#22c55e; font-weight:bold;">● LIVE</span>')
        return format_html('<span style="color:#94a3b8;">○ Off</span>')
    live_badge.short_description = 'Status'


# ═══════════════════════════════════════════════════════════════════
# FLASH SALE ADMIN
# ═══════════════════════════════════════════════════════════════════

class FlashSaleProductInline(admin.TabularInline):
    model = FlashSaleProduct
    extra = 1
    fields = (
        'product', 'discount_type', 'discount_value',
        'purchase_limit_total', 'max_per_user',
        'sort_order', 'is_active',
    )
    autocomplete_fields = ['product']


@admin.register(FlashSale)
class FlashSaleAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'live_badge', 'product_count',
        'priority', 'is_active',
        'starts_at', 'ends_at',
    )
    list_filter = (ActiveNowFilter, 'platform', 'audience')
    list_editable = ('priority', 'is_active')
    search_fields = ('title',)
    ordering = ['-priority', 'starts_at']
    inlines = [FlashSaleProductInline]

    fieldsets = (
        ('Sale Details', {
            'fields': ('title', 'description'),
        }),
        SCHEDULING_FIELDSET,
        TARGETING_FIELDSET,
    )

    def product_count(self, obj):
        return obj.sale_products.count()
    product_count.short_description = 'Products'

    def live_badge(self, obj):
        if obj.is_live:
            return format_html('<span style="color:#22c55e; font-weight:bold;">● LIVE</span>')
        return format_html('<span style="color:#94a3b8;">○ Off</span>')
    live_badge.short_description = 'Status'


# ═══════════════════════════════════════════════════════════════════
# FEATURED SECTION ADMIN
# ═══════════════════════════════════════════════════════════════════

@admin.register(FeaturedSection)
class FeaturedSectionAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'section_type', 'live_badge',
        'priority', 'is_active',
        'starts_at', 'ends_at',
    )
    list_filter = (ActiveNowFilter, 'section_type', 'platform', 'audience')
    list_editable = ('priority', 'is_active')
    search_fields = ('title',)
    ordering = ['-priority', 'starts_at']
    filter_horizontal = ('products',)

    fieldsets = (
        ('Section Details', {
            'fields': ('title', 'section_type', 'products'),
            'description': (
                'For CURATED: select products below. '
                'For Trending/New/Top Rated: products are fetched automatically (selection ignored).'
            ),
        }),
        SCHEDULING_FIELDSET,
        TARGETING_FIELDSET,
    )

    def live_badge(self, obj):
        if obj.is_live:
            return format_html('<span style="color:#22c55e; font-weight:bold;">● LIVE</span>')
        return format_html('<span style="color:#94a3b8;">○ Off</span>')
    live_badge.short_description = 'Status'
