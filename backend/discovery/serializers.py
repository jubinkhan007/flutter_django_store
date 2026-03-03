from __future__ import annotations

from rest_framework import serializers

from products.serializers import ProductSerializer
from promotions.serializers import CompactProductSerializer

from .models import Collection


class CollectionPreviewSerializer(serializers.ModelSerializer):
    banner_image_url = serializers.SerializerMethodField()

    class Meta:
        model = Collection
        fields = [
            'slug',
            'title',
            'subtitle',
            'banner_image_url',
            'starts_at',
            'ends_at',
        ]

    def get_banner_image_url(self, obj):
        request = self.context.get('request')
        if obj.banner_image and hasattr(obj.banner_image, 'url'):
            if request:
                return request.build_absolute_uri(obj.banner_image.url)
            return obj.banner_image.url
        return None


class DiscoveryHomeSerializer(serializers.Serializer):
    server_now = serializers.CharField()
    recently_viewed = CompactProductSerializer(many=True)
    recommended = CompactProductSerializer(many=True)
    trending = CompactProductSerializer(many=True)
    collections = CollectionPreviewSerializer(many=True)


class ProductRecommendationsSerializer(serializers.Serializer):
    similar_items = ProductSerializer(many=True)
    frequently_bought_together = ProductSerializer(many=True)

