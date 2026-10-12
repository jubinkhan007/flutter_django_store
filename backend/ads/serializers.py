from rest_framework import serializers
from decimal import Decimal
from django.utils import timezone
from .models import AdCampaign, AdImpression, AdClick
from products.models import Product, Category
from vendors.models import Vendor

class AdProductSummarySerializer(serializers.ModelSerializer):
    in_stock = serializers.BooleanField(read_only=True)

    class Meta:
        model = Product
        fields = ['id', 'name', 'price', 'stock_quantity', 'in_stock', 'image', 'is_available']

class AdCampaignSerializer(serializers.ModelSerializer):
    product_detail = AdProductSummarySerializer(source='product', read_only=True)
    impressions_count = serializers.SerializerMethodField()
    clicks_count = serializers.SerializerMethodField()
    ctr = serializers.SerializerMethodField()

    class Meta:
        model = AdCampaign
        fields = [
            'id',
            'vendor',
            'product',
            'product_detail',
            'budget_total',
            'budget_spent',
            'daily_budget',
            'cost_per_click',
            'status',
            'starts_at',
            'ends_at',
            'keywords',
            'is_sponsored_label_required',
            'impressions_count',
            'clicks_count',
            'ctr',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['vendor', 'budget_spent', 'created_at', 'updated_at']

    def get_impressions_count(self, obj):
        return getattr(obj, '_impressions_count', None) or obj.impressions.count()

    def get_clicks_count(self, obj):
        return getattr(obj, '_clicks_count', None) or obj.clicks.count()

    def get_ctr(self, obj):
        imp = self.get_impressions_count(obj)
        clk = self.get_clicks_count(obj)
        if imp > 0:
            return round((clk / imp) * 100.0, 2)
        return 0.0

class AdCampaignCreateSerializer(serializers.ModelSerializer):
    product_id = serializers.IntegerField(write_only=True)
    target_category_ids = serializers.ListField(
        child=serializers.IntegerField(), required=False, write_only=True
    )

    class Meta:
        model = AdCampaign
        fields = [
            'id',
            'product_id',
            'budget_total',
            'daily_budget',
            'cost_per_click',
            'starts_at',
            'ends_at',
            'keywords',
            'target_category_ids',
        ]

    def validate_product_id(self, value):
        vendor = self.context['request'].vendor
        try:
            product = Product.objects.get(id=value, vendor=vendor)
        except Product.DoesNotExist:
            raise serializers.ValidationError("Product not found or does not belong to your store.")

        if not product.is_available:
            raise serializers.ValidationError("Cannot create ad campaign for unavailable product.")
        return value

    def validate_budget_total(self, value):
        if value < Decimal('10.00'):
            raise serializers.ValidationError("Total budget must be at least 10.00.")
        return value

    def validate_cost_per_click(self, value):
        if value < Decimal('0.50'):
            raise serializers.ValidationError("Cost per click must be at least 0.50.")
        return value

    def create(self, validated_data):
        vendor = self.context['request'].vendor
        product_id = validated_data.pop('product_id')
        product = Product.objects.get(id=product_id)
        target_category_ids = validated_data.pop('target_category_ids', [])

        campaign = AdCampaign.objects.create(
            vendor=vendor,
            product=product,
            status=AdCampaign.Status.ACTIVE,
            **validated_data
        )

        if target_category_ids:
            categories = Category.objects.filter(id__in=target_category_ids)
            campaign.target_categories.set(categories)

        return campaign

class AdCampaignUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdCampaign
        fields = ['status', 'daily_budget', 'cost_per_click', 'budget_total', 'keywords', 'ends_at']

    def validate_status(self, value):
        allowed = [AdCampaign.Status.ACTIVE, AdCampaign.Status.PAUSED]
        if value not in allowed:
            raise serializers.ValidationError(f"Status can only be set to {allowed}.")
        return value

class AdTopupSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal('10.00'))

    def validate_amount(self, value):
        vendor = self.context['request'].vendor
        available = vendor.available_balance or Decimal('0.00')
        if value > available:
            raise serializers.ValidationError(
                f"Insufficient available earnings. You have {available} available to transfer."
            )
        return value

class AdImpressionSerializer(serializers.Serializer):
    campaign_id = serializers.IntegerField()
    session_id = serializers.UUIDField()
    source = serializers.CharField(max_length=50, default='HOME')

class AdClickSerializer(serializers.Serializer):
    campaign_id = serializers.IntegerField()
    session_id = serializers.UUIDField()
    click_id = serializers.UUIDField()
