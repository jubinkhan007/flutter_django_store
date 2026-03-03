from rest_framework import serializers
from .models import Order, SubOrder, OrderItem, ShipmentEvent
from products.serializers import ProductSerializer
from decimal import Decimal


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = [
            'id', 'product', 'variant', 'quantity',
            'product_title', 'variant_name', 'sku',
            'unit_price', 'tax', 'discount', 'image_url', 'total_price'
        ]


class ShipmentEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShipmentEvent
        fields = [
            'id',
            'status',
            'location',
            'timestamp',
            'description',
            'sequence',
            'source',
            'external_event_id',
        ]


class SubOrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    events = ShipmentEventSerializer(many=True, read_only=True)
    vendor_store_name = serializers.CharField(source='vendor.store_name', read_only=True)
    package_label = serializers.SerializerMethodField()
    order_id = serializers.IntegerField(source='order.id', read_only=True)
    payment_status = serializers.CharField(source='order.payment_status', read_only=True)
    payment_method = serializers.CharField(source='order.payment_method', read_only=True)
    total_amount = serializers.SerializerMethodField()

    class Meta:
        model = SubOrder
        fields = [
            'id', 'order_id', 'vendor', 'vendor_store_name', 'package_label', 'status',
            'courier_code', 'courier_name', 'tracking_number', 'tracking_url',
            'provision_status', 'courier_reference_id', 'last_error',
            'payment_status', 'payment_method', 'total_amount',
            'accepted_at', 'packed_at', 'shipped_at', 'delivered_at', 'canceled_at',
            'ship_by_date', 'created_at', 'updated_at', 'items', 'events'
        ]
        read_only_fields = ['vendor', 'vendor_store_name', 'order_id', 'created_at', 'updated_at']

    def get_package_label(self, obj):
        ids = list(obj.order.sub_orders.order_by('id').values_list('id', flat=True))
        try:
            idx = ids.index(obj.id) + 1
        except ValueError:
            idx = 1
        return f"Package {idx}"

    def get_total_amount(self, obj):
        total = Decimal('0.00')
        for item in obj.items.all():
            try:
                total += item.total_price
            except Exception:
                unit = item.unit_price or Decimal('0.00')
                total += (unit * item.quantity)
        return str(total.quantize(Decimal('0.01')))


class OrderCreateItemSerializer(serializers.Serializer):
    """
    A lightweight serializer just for creating orders.
    The customer only needs to send product ID + quantity + optional variant.
    """
    product = serializers.IntegerField()
    variant = serializers.IntegerField(required=False, allow_null=True)
    quantity = serializers.IntegerField(min_value=1)


class OrderSerializer(serializers.ModelSerializer):
    """
    Full order serializer — used when viewing orders.
    Shows the customer, status, total, and all items with their details.
    """
    sub_orders = SubOrderSerializer(many=True, read_only=True)
    items = serializers.SerializerMethodField()
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
            'delivered_at',
            'items',
            'sub_orders',
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
            'delivered_at',
            'items',
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

    def get_items(self, obj):
        """
        Backward-compatible flattened items list for mobile clients.
        """
        items = []
        for oi in OrderItem.objects.select_related('product').filter(sub_order__order=obj).order_by('id'):
            product_detail = None
            if oi.product_id:
                try:
                    product_detail = ProductSerializer(oi.product).data
                except Exception:
                    product_detail = None
            if product_detail is None:
                product_detail = {'name': oi.product_title}

            items.append(
                {
                    'id': oi.id,
                    'product': oi.product_id,
                    'quantity': oi.quantity,
                    'price': str(oi.unit_price),
                    'product_detail': product_detail,
                }
            )
        return items


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
