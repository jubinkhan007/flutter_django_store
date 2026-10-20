from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import action, display

from .models import LoyaltyAccount, LoyaltyTransaction


class LoyaltyTransactionInline(TabularInline):
    model = LoyaltyTransaction
    extra = 0
    fields = ('transaction_type', 'points_display', 'balance_after', 'order', 'description', 'created_at')
    readonly_fields = ('transaction_type', 'points_display', 'balance_after', 'order', 'description', 'created_at')
    can_delete = False
    tab = True

    @display(description='Points')
    def points_display(self, obj):
        color = 'text-emerald-600 font-bold' if obj.points > 0 else 'text-rose-600 font-bold'
        sign = '+' if obj.points > 0 else ''
        return format_html(f'<span class="{color}">{sign}{obj.points}</span>')


@admin.register(LoyaltyAccount)
class LoyaltyAccountAdmin(ModelAdmin):
    list_display = (
        'id',
        'user',
        'tier_badge',
        'points_balance',
        'points_value_display',
        'lifetime_points_earned',
        'lifetime_points_redeemed',
        'updated_at',
    )
    list_filter = ('tier', 'created_at', 'updated_at')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name')
    readonly_fields = ('created_at', 'updated_at', 'points_value_display')
    inlines = [LoyaltyTransactionInline]
    actions = ['grant_100_bonus_points', 'grant_500_bonus_points']

    @display(description='Tier')
    def tier_badge(self, obj):
        colors = {
            'BRONZE': 'badge-neutral',
            'SILVER': 'badge-info',
            'GOLD': 'badge-warning',
            'PLATINUM': 'badge-primary',
        }
        cls = colors.get(obj.tier, 'badge-neutral')
        return format_html(f'<span class="badge {cls} text-xs font-semibold">{obj.tier}</span>')

    @display(description='Fiat Value')
    def points_value_display(self, obj):
        return f"৳{obj.points_value_bdt:,.2f}"

    @action(description='⭐ Grant +100 bonus reward points')
    def grant_100_bonus_points(self, request, queryset):
        for acc in queryset:
            acc.points_balance += 100
            acc.lifetime_points_earned += 100
            acc.save(update_fields=['points_balance', 'lifetime_points_earned', 'updated_at'])
            acc.update_tier()
            LoyaltyTransaction.objects.create(
                account=acc,
                transaction_type=LoyaltyTransaction.Type.ADJUST,
                points=100,
                balance_after=acc.points_balance,
                description=f"Admin +100 bonus granted by {request.user.username}",
            )
        self.message_user(request, f"+100 points granted to {queryset.count()} accounts.")

    @action(description='⭐ Grant +500 bonus reward points')
    def grant_500_bonus_points(self, request, queryset):
        for acc in queryset:
            acc.points_balance += 500
            acc.lifetime_points_earned += 500
            acc.save(update_fields=['points_balance', 'lifetime_points_earned', 'updated_at'])
            acc.update_tier()
            LoyaltyTransaction.objects.create(
                account=acc,
                transaction_type=LoyaltyTransaction.Type.ADJUST,
                points=500,
                balance_after=acc.points_balance,
                description=f"Admin +500 bonus granted by {request.user.username}",
            )
        self.message_user(request, f"+500 points granted to {queryset.count()} accounts.")


@admin.register(LoyaltyTransaction)
class LoyaltyTransactionAdmin(ModelAdmin):
    list_display = (
        'id',
        'account',
        'transaction_type',
        'points_display',
        'balance_after',
        'order',
        'description',
        'created_at',
    )
    list_filter = ('transaction_type', 'created_at')
    search_fields = ('account__user__username', 'account__user__email', 'description')
    readonly_fields = ('created_at',)

    @display(description='Points')
    def points_display(self, obj):
        color = 'text-emerald-600 font-bold' if obj.points > 0 else 'text-rose-600 font-bold'
        sign = '+' if obj.points > 0 else ''
        return format_html(f'<span class="{color}">{sign}{obj.points}</span>')
