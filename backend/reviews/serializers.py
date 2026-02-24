from rest_framework import serializers
from .models import Review, ReviewReply


class ReviewReplySerializer(serializers.ModelSerializer):
    vendor_name = serializers.CharField(source='vendor.store_name', read_only=True)

    class Meta:
        model = ReviewReply
        fields = ['id', 'vendor_name', 'reply', 'created_at', 'updated_at']
        read_only_fields = ['id', 'vendor_name', 'created_at', 'updated_at']


class ReviewSerializer(serializers.ModelSerializer):
    customer_username = serializers.CharField(source='customer.username', read_only=True)
    reply = ReviewReplySerializer(read_only=True)

    class Meta:
        model = Review
        fields = [
            'id', 'customer', 'customer_username',
            'rating', 'comment', 'reply',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'customer', 'customer_username', 'created_at', 'updated_at']
