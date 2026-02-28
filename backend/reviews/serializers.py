from rest_framework import serializers
from .models import Review, ReviewReply, ReviewImage


class ReviewReplySerializer(serializers.ModelSerializer):
    vendor_name = serializers.CharField(source='vendor.store_name', read_only=True)

    class Meta:
        model = ReviewReply
        fields = ['id', 'vendor_name', 'reply', 'created_at', 'updated_at']
        read_only_fields = ['id', 'vendor_name', 'created_at', 'updated_at']


class ReviewImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewImage
        fields = ['id', 'image', 'created_at']
        read_only_fields = ['id', 'created_at']


class ReviewSerializer(serializers.ModelSerializer):
    customer_username = serializers.CharField(source='customer.username', read_only=True)
    reply = ReviewReplySerializer(read_only=True)
    images = ReviewImageSerializer(many=True, read_only=True)
    helpful_votes = serializers.IntegerField(read_only=True)

    class Meta:
        model = Review
        fields = [
            'id', 'customer', 'customer_username', 'product', 'sub_order',
            'rating', 'comment', 'images', 'is_verified_purchase', 'helpful_votes',
            'reply', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'customer', 'customer_username', 'images', 'helpful_votes',
            'is_verified_purchase', 'reply', 'created_at', 'updated_at'
        ]
