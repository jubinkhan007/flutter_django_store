from rest_framework import serializers

from .models import CrossBorderCostConfig, CrossBorderOrderRequest, CrossBorderProduct


class CrossBorderProductSerializer(serializers.ModelSerializer):
    primary_image = serializers.ReadOnlyField()

    class Meta:
        model = CrossBorderProduct
        fields = [
            'id', 'title', 'description', 'images', 'primary_image',
            'origin_marketplace', 'source_url',
            'base_price_foreign', 'currency', 'estimated_weight_kg',
            'category', 'is_active', 'priority', 'policy_summary',
            'lead_time_days_min', 'lead_time_days_max',
        ]


class CrossBorderCostConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = CrossBorderCostConfig
        fields = [
            'shipping_method', 'rate_per_kg', 'service_fee_type',
            'service_fee_value', 'customs_rate_percentage', 'fx_rate_bdt',
        ]


class CrossBorderOrderRequestSerializer(serializers.ModelSerializer):
    title = serializers.ReadOnlyField()
    is_quote_valid = serializers.ReadOnlyField()

    class Meta:
        model = CrossBorderOrderRequest
        fields = [
            'id', 'quote_id', 'request_type', 'title',
            'crossborder_product', 'source_url', 'marketplace',
            'variant_notes', 'quantity', 'shipping_method',
            'estimated_cost_breakdown', 'customs_policy_acknowledged',
            'is_quote_valid', 'quote_expires_at',
            'expected_delivery_days_min', 'expected_delivery_days_max',
            'status',
            'carrier_name', 'tracking_number', 'tracking_url',
            'supplier_order_id',
            'created_at', 'quoted_at', 'ordered_at',
            'shipped_intl_at', 'delivered_at',
        ]
        read_only_fields = [
            'id', 'quote_id', 'title', 'is_quote_valid',
            'estimated_cost_breakdown', 'quote_expires_at',
            'status', 'delivery_mode',
            'created_at', 'quoted_at', 'ordered_at',
            'shipped_intl_at', 'delivered_at',
        ]


class CBRequestCreateSerializer(serializers.Serializer):
    request_type = serializers.ChoiceField(choices=CrossBorderOrderRequest.RequestType.choices)
    crossborder_product_id = serializers.IntegerField(required=False, allow_null=True)
    source_url = serializers.URLField(required=False, allow_blank=True)
    marketplace = serializers.ChoiceField(
        choices=CrossBorderOrderRequest.Marketplace.choices,
        default=CrossBorderOrderRequest.Marketplace.OTHER,
    )
    variant_notes = serializers.CharField(required=False, allow_blank=True, default='')
    quantity = serializers.IntegerField(min_value=1, default=1)
    shipping_method = serializers.ChoiceField(
        choices=CrossBorderOrderRequest.ShippingMethod.choices,
        default=CrossBorderOrderRequest.ShippingMethod.AIR,
    )
    address_id = serializers.IntegerField(required=False, allow_null=True)
    address_snapshot = serializers.DictField(required=False, default=dict)
    customs_policy_acknowledged = serializers.BooleanField(default=False)

    def validate(self, data):
        if data.get('request_type') == CrossBorderOrderRequest.RequestType.CATALOG_ITEM:
            if not data.get('crossborder_product_id'):
                raise serializers.ValidationError('crossborder_product_id is required for CATALOG_ITEM requests.')
        if data.get('request_type') == CrossBorderOrderRequest.RequestType.LINK_PURCHASE:
            if not data.get('source_url'):
                raise serializers.ValidationError('source_url is required for LINK_PURCHASE requests.')
        return data


class CBCheckoutSerializer(serializers.Serializer):
    customs_policy_acknowledged = serializers.BooleanField()


# Admin ops serializers
class CBMarkOrderedSerializer(serializers.Serializer):
    supplier_order_id = serializers.CharField(max_length=255)
    ops_notes = serializers.CharField(required=False, allow_blank=True)


class CBMarkShippedSerializer(serializers.Serializer):
    carrier_name = serializers.CharField(max_length=100)
    tracking_number = serializers.CharField(max_length=255)
    tracking_url = serializers.URLField(required=False, allow_blank=True)


class CBMarkCustomsHeldSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default='')


class CBFinalizeCostSerializer(serializers.Serializer):
    realized_item_cost_bdt = serializers.DecimalField(max_digits=14, decimal_places=2)
    realized_shipping_bdt = serializers.DecimalField(max_digits=14, decimal_places=2)
    ops_notes = serializers.CharField(required=False, allow_blank=True)
