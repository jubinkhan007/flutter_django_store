from __future__ import annotations

from rest_framework import serializers

from .models import Conversation, ChatMessage
from products.models import Product
from orders.models import Order
from vendors.models import Vendor


class ChatMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    is_me = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ChatMessage
        fields = [
            'id',
            'conversation',
            'sender',
            'sender_name',
            'sender_type',
            'message_type',
            'text',
            'image',
            'image_url',
            'is_read',
            'is_me',
            'created_at',
        ]
        read_only_fields = ['id', 'conversation', 'sender', 'sender_type', 'is_read', 'created_at']

    def get_sender_name(self, obj) -> str:
        if obj.sender_type == ChatMessage.SenderType.VENDOR:
            return obj.conversation.vendor.store_name
        return obj.sender.get_full_name() or obj.sender.username

    def get_is_me(self, obj) -> bool:
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return obj.sender_id == request.user.id

    def get_image_url(self, obj) -> str | None:
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class ChatProductSummarySerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = ['id', 'name', 'price', 'image_url']

    def get_image_url(self, obj) -> str | None:
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class ChatOrderSummarySerializer(serializers.ModelSerializer):
    order_number = serializers.CharField(source='tracking_number', read_only=True)

    class Meta:
        model = Order
        fields = ['id', 'order_number', 'status', 'total_amount', 'created_at']


class ConversationListSerializer(serializers.ModelSerializer):
    vendor_id = serializers.IntegerField(source='vendor.id', read_only=True)
    vendor_name = serializers.CharField(source='vendor.store_name', read_only=True)
    vendor_logo = serializers.SerializerMethodField()
    customer_id = serializers.IntegerField(source='customer.id', read_only=True)
    customer_name = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    product = ChatProductSummarySerializer(read_only=True)
    order = ChatOrderSummarySerializer(read_only=True)

    class Meta:
        model = Conversation
        fields = [
            'id',
            'vendor_id',
            'vendor_name',
            'vendor_logo',
            'customer_id',
            'customer_name',
            'last_message_preview',
            'last_message_at',
            'unread_count',
            'product',
            'order',
            'created_at',
            'updated_at',
        ]

    def get_vendor_logo(self, obj) -> str | None:
        if obj.vendor.logo:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.vendor.logo.url)
            return obj.vendor.logo.url
        return None

    def get_customer_name(self, obj) -> str:
        return obj.customer.get_full_name() or obj.customer.username

    def get_unread_count(self, obj) -> int:
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return 0
        user = request.user
        if hasattr(user, 'vendor_profile') and user.vendor_profile == obj.vendor:
            return obj.vendor_unread_count
        return obj.customer_unread_count


class ConversationDetailSerializer(ConversationListSerializer):
    messages = ChatMessageSerializer(many=True, read_only=True)

    class Meta(ConversationListSerializer.Meta):
        fields = ConversationListSerializer.Meta.fields + ['messages']


class StartConversationSerializer(serializers.Serializer):
    vendor_id = serializers.IntegerField(required=True)
    product_id = serializers.IntegerField(required=False, allow_null=True)
    order_id = serializers.IntegerField(required=False, allow_null=True)
    message = serializers.CharField(required=False, allow_blank=True, default='')

    def validate_vendor_id(self, value):
        if not Vendor.objects.filter(id=value).exists():
            raise serializers.ValidationError("Vendor not found.")
        return value

    def validate_product_id(self, value):
        if value and not Product.objects.filter(id=value).exists():
            raise serializers.ValidationError("Product not found.")
        return value

    def validate_order_id(self, value):
        if value and not Order.objects.filter(id=value).exists():
            raise serializers.ValidationError("Order not found.")
        return value


class SendMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = ['text', 'image', 'message_type']

    def validate(self, attrs):
        text = attrs.get('text', '').strip()
        image = attrs.get('image')
        if not text and not image:
            raise serializers.ValidationError("Either text or image must be provided.")
        return attrs
