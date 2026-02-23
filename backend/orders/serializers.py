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

    class Meta:
        model = Order
        fields = ['id', 'customer', 'total_amount', 'status', 'items', 'created_at', 'updated_at']
        read_only_fields = ['customer', 'total_amount', 'status', 'created_at', 'updated_at']


class OrderCreateSerializer(serializers.Serializer):
    """
    Used when a customer PLACES an order.
    
    The customer sends a list of items:
    {
        "items": [
            {"product": 1, "quantity": 2},
            {"product": 5, "quantity": 1}
        ]
    }
    
    The backend then:
    1. Looks up each product to get the price and vendor
    2. Calculates the total
    3. Creates the Order and OrderItems
    4. Decreases stock quantities
    """
    items = OrderCreateItemSerializer(many=True)

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError("You must include at least one item.")
        return value
