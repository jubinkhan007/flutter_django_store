from rest_framework import serializers
from django.utils import timezone
from .models import Category, Product, ProductOption, ProductOptionValue, ProductVariant

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'description', 'image']

class ProductOptionValueSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductOptionValue
        fields = ['id', 'value', 'slug']

class ProductOptionSerializer(serializers.ModelSerializer):
    values = ProductOptionValueSerializer(many=True, read_only=True)
    
    class Meta:
        model = ProductOption
        fields = ['id', 'name', 'slug', 'values']

class ProductVariantSerializer(serializers.ModelSerializer):
    option_value_ids = serializers.PrimaryKeyRelatedField(
        many=True, read_only=True, source='option_values'
    )
    stock_available = serializers.IntegerField(source='available_stock', read_only=True)
    effective_price = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)

    class Meta:
        model = ProductVariant
        fields = [
            'id', 'sku', 'barcode', 'price_override', 'effective_price',
            'stock_on_hand', 'reserved_stock', 'low_stock_threshold', 'stock_available',
            'is_active', 'option_value_ids'
        ]

class ProductSerializer(serializers.ModelSerializer):
    """
    Serializer for the Product model.
    Includes the Category details if needed.
    """

    category_detail = CategorySerializer(source='category', read_only=True)
    options = ProductOptionSerializer(many=True, read_only=True)
    variants = ProductVariantSerializer(many=True, read_only=True)
    active_sale_price = serializers.SerializerMethodField()

    def get_active_sale_price(self, obj):
        """Return the current active flash sale price for this product, or null."""
        from promotions.models import FlashSaleProduct
        now = timezone.now()
        fsp = FlashSaleProduct.objects.filter(
            product=obj,
            is_active=True,
            flash_sale__is_active=True,
            flash_sale__starts_at__lte=now,
            flash_sale__ends_at__gte=now,
        ).first()
        if fsp:
            return str(fsp.effective_sale_price)
        return None

    class Meta:
        model = Product
        fields = [
            'id',
            'vendor',
            'category',
            'category_detail',
            'name',
            'description',
            'price',
            'active_sale_price',
            'stock_quantity',
            'image',
            'is_available',
            'in_stock',
            'options',
            'variants',
            'created_at',
            'updated_at'
        ]
        read_only_fields = ['vendor', 'created_at', 'updated_at', 'in_stock']

from .models import Wishlist

class WishlistSerializer(serializers.ModelSerializer):
    product_detail = ProductSerializer(source='product', read_only=True)

    class Meta:
        model = Wishlist
        fields = ['id', 'user', 'product', 'product_detail', 'added_at']
        read_only_fields = ['user', 'added_at']
