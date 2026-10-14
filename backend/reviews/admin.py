from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline, StackedInline
from unfold.decorators import display

from .models import Review, ReviewHelpfulness, ReviewImage, ReviewReply


class ReviewImageInline(TabularInline):
    model = ReviewImage
    extra = 0
    show_all_pages = True
    fields = ('image', 'thumbnail_preview', 'position', 'created_at')
    readonly_fields = ('thumbnail_preview', 'created_at')
    tab = True

    @display(description='Preview')
    def thumbnail_preview(self, obj):
        if obj.image:
            return format_html(
                '<a href="{0}" target="_blank">'
                '<img src="{0}" class="h-14 w-14 rounded object-cover border border-base-200 shadow-xs" />'
                '</a>',
                obj.image.url,
            )
        return "—"


class ReviewReplyInline(StackedInline):
    model = ReviewReply
    extra = 0
    fields = ('vendor', 'reply', 'created_at')
    readonly_fields = ('created_at',)
    tab = True


@admin.register(Review)
class ReviewAdmin(ModelAdmin):
    list_display = (
        'id',
        'customer',
        'product',
        'show_rating_stars',
        'show_verified',
        'show_images_count',
        'show_helpful_votes',
        'show_has_reply',
        'created_at',
    )
    list_filter = ('rating', 'is_verified_purchase')
    list_select_related = ('customer', 'product')
    search_fields = ('id', 'customer__email', 'customer__username', 'product__name', 'comment')
    date_hierarchy = 'created_at'
    inlines = [ReviewImageInline, ReviewReplyInline]
    actions = ['mark_as_verified', 'unmark_as_verified']

    fieldsets = (
        ('Review Content', {
            'fields': ('customer', 'product', 'rating', 'comment'),
            'classes': ['tab'],
        }),
        ('Verification & Order Link', {
            'fields': ('is_verified_purchase', 'sub_order'),
            'classes': ['tab'],
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ['tab'],
        }),
    )

    readonly_fields = ('created_at', 'updated_at')

    @display(description='Rating')
    def show_rating_stars(self, obj):
        stars = '★' * obj.rating + '☆' * (5 - obj.rating)
        color_class = "text-amber-500 font-bold"
        return format_html('<span class="{}">{} ({}★)</span>', color_class, stars, obj.rating)

    @display(description='Verified', label={True: 'success', False: 'secondary'})
    def show_verified(self, obj):
        return obj.is_verified_purchase

    @display(description='Photos')
    def show_images_count(self, obj):
        cnt = obj.images.count()
        return f"{cnt} photo(s)" if cnt > 0 else "—"

    @display(description='Helpful Votes')
    def show_helpful_votes(self, obj):
        return obj.helpful_votes.count()

    @display(description='Vendor Reply', label={True: 'info', False: 'secondary'})
    def show_has_reply(self, obj):
        return hasattr(obj, 'reply') and obj.reply is not None

    @admin.action(description="Mark selected reviews as Verified Purchase")
    def mark_as_verified(self, request, queryset):
        updated = queryset.update(is_verified_purchase=True)
        self.message_user(request, f"{updated} review(s) marked as verified purchase.")

    @admin.action(description="Remove Verified status from selected reviews")
    def unmark_as_verified(self, request, queryset):
        updated = queryset.update(is_verified_purchase=False)
        self.message_user(request, f"{updated} review(s) unmarked as verified.")


@admin.register(ReviewHelpfulness)
class ReviewHelpfulnessAdmin(ModelAdmin):
    list_display = ('id', 'review', 'user', 'created_at')
    list_select_related = ('review', 'user', 'review__product')
    search_fields = ('user__email', 'user__username', 'review__product__name')
    date_hierarchy = 'created_at'
    readonly_fields = ('review', 'user', 'created_at')

    def has_add_permission(self, request):
        return False
