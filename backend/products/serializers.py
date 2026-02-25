from rest_framework import serializers
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
    
    # We can nest the Category details nicely for reads (GET requests)
    # Instead of just showing category_id = 1, it will show {"id": 1, "name": "Electronics"}
    category_detail = CategorySerializer(source='category', read_only=True)
    
    options = ProductOptionSerializer(many=True, read_only=True)
    variants = ProductVariantSerializer(many=True, read_only=True)

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
            'stock_quantity', 
            'image', 
            'is_available', 
            'in_stock',  # This comes from the @property method in the Model
            'options',
            'variants',
            'created_at', 
            'updated_at'
        ]
        # The vendor should be tied to the logged-in user automatically,
        # so vendors cannot forge or edit the vendor ID manually.
        read_only_fields = ['vendor', 'created_at', 'updated_at', 'in_stock']

from .models import Wishlist

class WishlistSerializer(serializers.ModelSerializer):
    product_detail = ProductSerializer(source='product', read_only=True)

    class Meta:
        model = Wishlist
        fields = ['id', 'user', 'product', 'product_detail', 'added_at']
        read_only_fields = ['user', 'added_at']
