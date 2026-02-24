from rest_framework import serializers
from .models import Order, OrderItem
from products.serializers import ProductSerializer


class OrderItemSerializer(serializers.ModelSerializer):
    """
    Serializer for individual items in an order.
    
    When CREATING an order, the customer sends:
      {"product": 5, "quantity": 2}
    
    When READING an order, we show full product details:
      {"product": 5, "product_detail": {"name": "...", "price": "..."}, "quantity": 2, ...}
    """
    # For read operations, include full product details
    product_detail = ProductSerializer(source='product', read_only=True)

    class Meta:
        model = OrderItem
        fields = ['id', 'product', 'product_detail', 'vendor', 'quantity', 'price']
        read_only_fields = ['vendor', 'price']  # Set automatically from the product


class OrderCreateItemSerializer(serializers.Serializer):
    """
    A lightweight serializer just for creating orders.
    The customer only needs to send product ID + quantity.
    """
    product = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)


class OrderSerializer(serializers.ModelSerializer):
    """
    Full order serializer — used when viewing orders.
    Shows the customer, status, total, and all items with their details.
    """
    items = OrderItemSerializer(many=True, read_only=True)
    customer_detail = serializers.SerializerMethodField()
    delivery_address = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            'id',
            'customer',
            'customer_detail',
            'delivery_address',
            'coupon',
            'subtotal_amount',
            'discount_amount',
            'total_amount',
            'status',
            'payment_method',
            'payment_status',
            'transaction_id',
            'val_id',
            'items',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'customer',
            'coupon',
            'subtotal_amount',
            'discount_amount',
            'total_amount',
            'status',
            'payment_method',
            'payment_status',
            'transaction_id',
            'val_id',
            'created_at',
            'updated_at',
        ]

    def get_customer_detail(self, obj):
        return {
            'id': obj.customer.id,
            'username': obj.customer.username,
            'email': obj.customer.email,
        }
        
    def get_delivery_address(self, obj):
        if not obj.delivery_address:
            return None
        address = obj.delivery_address
        return {
            'id': address.id,
            'label': address.label,
            'phone_number': address.phone_number,
            'address_line': address.address_line,
            'area': address.area,
            'city': address.city,
        }


class OrderCreateSerializer(serializers.Serializer):
    """
    Used when a customer PLACES an order.
    """
    items = OrderCreateItemSerializer(many=True)
    address_id = serializers.IntegerField(required=True)
    payment_method = serializers.ChoiceField(
        choices=Order.PaymentMethod.choices,
        required=False,
        default=Order.PaymentMethod.ONLINE,
    )
    coupon_code = serializers.CharField(required=False, allow_blank=True)

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError("You must include at least one item.")
        return value
