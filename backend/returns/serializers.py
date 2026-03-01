from decimal import Decimal

from rest_framework import serializers

from orders.models import Order, OrderItem
from products.serializers import ProductSerializer

from .models import Refund, ReturnImage, ReturnItem, ReturnRequest
from .models import ReturnPolicy
from products.models import Product, Category


class ReturnItemCreateSerializer(serializers.Serializer):
    order_item_id = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)
    condition = serializers.ChoiceField(choices=ReturnRequest.ItemCondition.choices, required=False)


class ReturnCreateSerializer(serializers.Serializer):
    order_id = serializers.IntegerField()
    request_type = serializers.ChoiceField(choices=ReturnRequest.RequestType.choices)
    reason = serializers.ChoiceField(choices=ReturnRequest.Reason.choices)
    reason_details = serializers.CharField(required=False, allow_blank=True)
    customer_note = serializers.CharField(required=False, allow_blank=True)
    fulfillment = serializers.ChoiceField(choices=ReturnRequest.Fulfillment.choices, required=False)
    refund_method_preference = serializers.ChoiceField(choices=ReturnRequest.RefundMethod.choices, required=False)
    items = ReturnItemCreateSerializer(many=True)


class ReturnImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReturnImage
        fields = ['id', 'image', 'uploaded_at']


class ReturnItemSerializer(serializers.ModelSerializer):
    product_detail = ProductSerializer(source='order_item.product', read_only=True)

    class Meta:
        model = ReturnItem
        fields = ['id', 'order_item', 'product_detail', 'quantity', 'condition']


class RefundSerializer(serializers.ModelSerializer):
    class Meta:
        model = Refund
        fields = [
            'id',
            'amount',
            'method',
            'status',
            'provider',
            'provider_ref_id',
            'provider_trans_id',
            'processed_at',
            'reference',
            'failure_reason',
            'created_at',
            'updated_at',
        ]


class ReturnRequestSerializer(serializers.ModelSerializer):
    items = ReturnItemSerializer(many=True, read_only=True)
    images = ReturnImageSerializer(many=True, read_only=True)
    refunds = RefundSerializer(many=True, read_only=True)

    class Meta:
        model = ReturnRequest
        fields = [
            'id',
            'rma_number',
            'order',
            'customer',
            'vendor',
            'request_type',
            'status',
            'reason',
            'reason_details',
            'fulfillment',
            'pickup_window_start',
            'pickup_window_end',
            'dropoff_instructions',
            'refund_method_preference',
            'vendor_response_due_at',
            'escalated_at',
            'approved_at',
            'rejected_at',
            'received_at',
            'vendor_note',
            'customer_note',
            'items',
            'images',
            'refunds',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields


class VendorReturnActionSerializer(serializers.Serializer):
    note = serializers.CharField(required=False, allow_blank=True)
    pickup_window_start = serializers.DateTimeField(required=False)
    pickup_window_end = serializers.DateTimeField(required=False)
    dropoff_instructions = serializers.CharField(required=False, allow_blank=True)


class VendorRefundActionSerializer(serializers.Serializer):
    method = serializers.ChoiceField(choices=ReturnRequest.RefundMethod.choices)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)

    def validate_amount(self, value: Decimal):
        if value <= 0:
            raise serializers.ValidationError('Amount must be > 0.')
        return value


class VendorRefundCompleteSerializer(serializers.Serializer):
    reference = serializers.CharField(required=False, allow_blank=True)


class VendorReturnPolicySerializer(serializers.ModelSerializer):
    class Meta:
        model = ReturnPolicy
        fields = [
            'id',
            'name',
            'vendor',
            'category',
            'product',
            'return_window_days',
            'sealed_return_window_days',
            'allow_return',
            'allow_replace',
            'sealed_requires_unopened',
            'notes',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['vendor', 'created_at', 'updated_at']

    def validate(self, attrs):
        request = self.context['request']
        vendor = request.user.vendor_profile

        product = attrs.get('product') if 'product' in attrs else getattr(self.instance, 'product', None)
        if product and product.vendor_id != vendor.id:
            raise serializers.ValidationError({'product': 'You can only set policies for your own products.'})

        return attrs

    def create(self, validated_data):
        request = self.context['request']
        vendor = request.user.vendor_profile
        return ReturnPolicy.objects.create(vendor=vendor, **validated_data)
