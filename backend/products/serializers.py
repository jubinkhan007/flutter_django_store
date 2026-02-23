from rest_framework import serializers
from .models import Category, Product

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'description', 'image']


class ProductSerializer(serializers.ModelSerializer):
    """
    Serializer for the Product model.
    Includes the Category details if needed.
    """
    
    # We can nest the Category details nicely for reads (GET requests)
    # Instead of just showing category_id = 1, it will show {"id": 1, "name": "Electronics"}
    category_detail = CategorySerializer(source='category', read_only=True)

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
            'created_at', 
            'updated_at'
        ]
        # The vendor should be tied to the logged-in user automatically,
        # so vendors cannot forge or edit the vendor ID manually.
        read_only_fields = ['vendor', 'created_at', 'updated_at', 'in_stock']
