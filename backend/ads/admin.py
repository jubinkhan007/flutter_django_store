from django.contrib import admin
from django.utils import timezone
from unfold.admin import ModelAdmin
from unfold.decorators import display

from .models import AdCampaign, AdImpression, AdClick


@admin.register(AdCampaign)
class AdCampaignAdmin(ModelAdmin):
    list_display = (
        'id',
        'vendor',
        'product',
        'show_status',
        'cost_per_click',
        'budget_spent_display',
        'budget_total',
        'show_budget_progress',
        'show_impressions_count',
        'show_clicks_count',
        'show_ctr',
        'created_at',
    )
    list_filter = ('status', 'is_sponsored_label_required')
    list_select_related = ('vendor', 'product')
    search_fields = ('id', 'vendor__store_name', 'product__name')
    date_hierarchy = 'created_at'
    actions = ['pause_campaigns', 'resume_campaigns', 'mark_as_exhausted']
    filter_horizontal = ('target_categories',)

    fieldsets = (
        ('Campaign Information', {
            'fields': ('vendor', 'product', 'status', 'is_sponsored_label_required'),
            'classes': ['tab'],
        }),
        ('Budget & Bidding', {
            'fields': (
                'budget_total',
                'budget_spent',
                'daily_budget',
                'cost_per_click',
                'starts_at',
                'ends_at',
            ),
            'classes': ['tab'],
        }),
        ('Targeting & Keywords', {
            'fields': ('keywords', 'target_categories'),
            'classes': ['tab'],
        }),
    )

    @display(description='Status', label={
        AdCampaign.Status.DRAFT: 'secondary',
        AdCampaign.Status.ACTIVE: 'success',
        AdCampaign.Status.PAUSED: 'warning',
        AdCampaign.Status.EXHAUSTED: 'danger',
    })
    def show_status(self, obj):
        return obj.status

    @display(description='Spent (৳)')
    def budget_spent_display(self, obj):
        return f"৳{obj.budget_spent:,.2f}"

    @display(description='Progress')
    def show_budget_progress(self, obj):
        if not obj.budget_total or obj.budget_total <= 0:
            return "0%"
        pct = (obj.budget_spent / obj.budget_total) * 100
        return f"{min(pct, 100.0):.1f}%"

    @display(description='Impressions')
    def show_impressions_count(self, obj):
        return obj.impressions.count()

    @display(description='Clicks')
    def show_clicks_count(self, obj):
        return obj.clicks.count()

    @display(description='CTR%')
    def show_ctr(self, obj):
        imp = obj.impressions.count()
        if imp == 0:
            return "0.00%"
        clicks = obj.clicks.count()
        ctr = (clicks / imp) * 100.0
        return f"{ctr:.2f}%"

    @admin.action(description="Pause selected campaigns")
    def pause_campaigns(self, request, queryset):
        updated = queryset.filter(status=AdCampaign.Status.ACTIVE).update(
            status=AdCampaign.Status.PAUSED,
            updated_at=timezone.now(),
        )
        self.message_user(request, f"{updated} campaign(s) paused.")

    @admin.action(description="Resume selected campaigns")
    def resume_campaigns(self, request, queryset):
        count = 0
        for campaign in queryset.filter(status=AdCampaign.Status.PAUSED):
            if campaign.budget_spent < campaign.budget_total:
                campaign.status = AdCampaign.Status.ACTIVE
                campaign.save(update_fields=['status', 'updated_at'])
                count += 1
        self.message_user(request, f"{count} campaign(s) resumed.")

    @admin.action(description="Mark selected campaigns as Exhausted")
    def mark_as_exhausted(self, request, queryset):
        updated = queryset.exclude(status=AdCampaign.Status.EXHAUSTED).update(
            status=AdCampaign.Status.EXHAUSTED,
            updated_at=timezone.now(),
        )
        self.message_user(request, f"{updated} campaign(s) marked as exhausted.")


@admin.register(AdImpression)
class AdImpressionAdmin(ModelAdmin):
    list_display = ('id', 'campaign', 'user', 'source', 'minute_bucket', 'created_at')
    list_filter = ('source',)
    list_select_related = ('campaign', 'user')
    search_fields = ('campaign__id', 'user__username', 'session_id')
    date_hierarchy = 'created_at'
    readonly_fields = ('campaign', 'user', 'session_id', 'source', 'minute_bucket', 'created_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(AdClick)
class AdClickAdmin(ModelAdmin):
    list_display = ('id', 'campaign', 'user', 'click_id', 'session_id', 'created_at')
    list_select_related = ('campaign', 'user')
    search_fields = ('campaign__id', 'user__username', 'click_id', 'session_id')
    date_hierarchy = 'created_at'
    readonly_fields = ('campaign', 'user', 'session_id', 'click_id', 'created_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
