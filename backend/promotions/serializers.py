# ═══════════════════════════════════════════════════════════════════
# PROMOTIONS SERIALIZERS
# ═══════════════════════════════════════════════════════════════════

from rest_framework import serializers
from .models import Banner, FlashSale, FlashSaleProduct, FeaturedSection
from products.models import Product


class CompactProductSerializer(serializers.ModelSerializer):
    """
    Lightweight product payload for home feed cards.
    Only the fields needed to render a compact product card.
    """
    vendor_name = serializers.SerializerMethodField()
    thumbnail = serializers.SerializerMethodField()
    rating = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = ['id', 'name', 'price', 'thumbnail', 'rating', 'vendor_name', 'stock_quantity', 'is_available']

    def get_vendor_name(self, obj):
        return obj.vendor.store_name if obj.vendor else None

    def get_thumbnail(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

    def get_rating(self, obj):
        # Average rating from reviews
        reviews = obj.reviews.all()
        if reviews.exists():
            from django.db.models import Avg
            return round(reviews.aggregate(avg=Avg('rating'))['avg'] or 0, 1)
        return None


class BannerSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Banner
        fields = [
            'id', 'title', 'subtitle', 'image_url',
            'link_type', 'link_value',
            'priority', 'starts_at', 'ends_at',
        ]

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class FlashSaleProductSerializer(serializers.ModelSerializer):
    product = CompactProductSerializer(read_only=True)
    effective_sale_price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
    )

    class Meta:
        model = FlashSaleProduct
        fields = [
            'id', 'product', 'discount_type', 'discount_value',
            'effective_sale_price', 'purchase_limit_total',
            'max_per_user', 'sort_order',
        ]


class FlashSaleSerializer(serializers.ModelSerializer):
    products = serializers.SerializerMethodField()

    class Meta:
        model = FlashSale
        fields = [
            'id', 'title', 'description',
            'starts_at', 'ends_at', 'products',
        ]

    def get_products(self, obj):
        active_items = obj.sale_products.filter(is_active=True).select_related('product__vendor')
        return FlashSaleProductSerializer(
            active_items,
            many=True,
            context=self.context,
        ).data


class FeaturedSectionSerializer(serializers.ModelSerializer):
    products = serializers.SerializerMethodField()

    class Meta:
        model = FeaturedSection
        fields = [
            'id', 'title', 'section_type',
            'priority', 'products',
        ]

    def get_products(self, obj):
        from django.db.models import Avg

        if obj.section_type == FeaturedSection.SectionType.CURATED:
            qs = obj.products.filter(is_available=True).select_related('vendor')
        elif obj.section_type == FeaturedSection.SectionType.NEW_ARRIVALS:
            qs = Product.objects.filter(is_available=True).select_related('vendor').order_by('-created_at')[:12]
        elif obj.section_type == FeaturedSection.SectionType.TOP_RATED:
            qs = Product.objects.filter(
                is_available=True,
                reviews__isnull=False,
            ).select_related('vendor').annotate(
                avg_rating=Avg('reviews__rating')
            ).order_by('-avg_rating')[:12]
        elif obj.section_type == FeaturedSection.SectionType.TRENDING:
            # Trending = most ordered in last 30 days
            from django.utils import timezone
            from datetime import timedelta
            from django.db.models import Count
            thirty_days = timezone.now() - timedelta(days=30)
            qs = Product.objects.filter(
                is_available=True,
                orderitem__sub_order__created_at__gte=thirty_days,
            ).select_related('vendor').annotate(
                order_count=Count('orderitem')
            ).order_by('-order_count')[:12]
        else:
            qs = Product.objects.none()

        return CompactProductSerializer(qs, many=True, context=self.context).data
