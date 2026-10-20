from __future__ import annotations

from decimal import Decimal
from rest_framework import serializers

from .models import LoyaltyAccount, LoyaltyTransaction


class LoyaltyTransactionSerializer(serializers.ModelSerializer):
    order_id = serializers.IntegerField(source='order.id', read_only=True, allow_null=True)

    class Meta:
        model = LoyaltyTransaction
        fields = [
            'id',
            'transaction_type',
            'points',
            'balance_after',
            'order_id',
            'description',
            'created_at',
        ]


class LoyaltyAccountSummarySerializer(serializers.ModelSerializer):
    points_value_bdt = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    tier_multiplier = serializers.FloatField(read_only=True)
    next_tier_info = serializers.DictField(read_only=True)
    recent_transactions = serializers.SerializerMethodField()

    class Meta:
        model = LoyaltyAccount
        fields = [
            'points_balance',
            'lifetime_points_earned',
            'lifetime_points_redeemed',
            'tier',
            'tier_multiplier',
            'points_value_bdt',
            'next_tier_info',
            'recent_transactions',
            'updated_at',
        ]

    def get_recent_transactions(self, obj) -> list[dict]:
        recent = obj.transactions.all()[:10]
        return LoyaltyTransactionSerializer(recent, many=True).data


class QuoteRedemptionSerializer(serializers.Serializer):
    points = serializers.IntegerField(min_value=1, required=True)

    def validate_points(self, value):
        user = self.context['request'].user
        account, _ = LoyaltyAccount.objects.get_or_create(user=user)
        if value > account.points_balance:
            raise serializers.ValidationError(
                f"You only have {account.points_balance} points available."
            )
        return value
