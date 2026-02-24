from rest_framework import serializers

from products.models import Product, Category

from .models import Coupon


class CouponValidateItemSerializer(serializers.Serializer):
    product = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)


class CouponValidateSerializer(serializers.Serializer):
    code = serializers.CharField()
    items = CouponValidateItemSerializer(many=True)

class CouponAvailableSerializer(serializers.Serializer):
    items = CouponValidateItemSerializer(many=True)


class VendorCouponSerializer(serializers.ModelSerializer):
    product_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        allow_empty=True,
        write_only=True,
    )
    category_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        allow_empty=True,
        write_only=True,
    )
    applicable_products = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    applicable_categories = serializers.PrimaryKeyRelatedField(many=True, read_only=True)

    class Meta:
        model = Coupon
        fields = [
            'id',
            'code',
            'discount_type',
            'discount_value',
            'min_order_amount',
            'is_active',
            'applicable_products',
            'applicable_categories',
            'product_ids',
            'category_ids',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def validate_code(self, value):
        return value.strip().upper()

    def create(self, validated_data):
        product_ids = validated_data.pop('product_ids', [])
        category_ids = validated_data.pop('category_ids', [])

        request = self.context['request']
        vendor = request.user.vendor_profile

        coupon = Coupon.objects.create(
            scope=Coupon.Scope.VENDOR,
            vendor=vendor,
            created_by=request.user,
            **validated_data,
        )

        if product_ids:
            products = Product.objects.filter(id__in=product_ids, vendor=vendor)
            if products.count() != len(set(product_ids)):
                raise serializers.ValidationError({'product_ids': 'Some products are invalid or not yours.'})
            coupon.applicable_products.set(products)

        if category_ids:
            categories = Category.objects.filter(id__in=category_ids)
            coupon.applicable_categories.set(categories)

        return coupon

    def update(self, instance, validated_data):
        product_ids = validated_data.pop('product_ids', None)
        category_ids = validated_data.pop('category_ids', None)

        for attr, val in validated_data.items():
            setattr(instance, attr, val)
        instance.save()

        vendor = instance.vendor
        if product_ids is not None:
            products = Product.objects.filter(id__in=product_ids, vendor=vendor)
            if products.count() != len(set(product_ids)):
                raise serializers.ValidationError({'product_ids': 'Some products are invalid or not yours.'})
            instance.applicable_products.set(products)

        if category_ids is not None:
            categories = Category.objects.filter(id__in=category_ids)
            instance.applicable_categories.set(categories)

        return instance


class PublicCouponSerializer(serializers.ModelSerializer):
    vendor_name = serializers.CharField(source='vendor.store_name', read_only=True)
    applicable_product_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        read_only=True,
        source='applicable_products',
    )
    applicable_category_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        read_only=True,
        source='applicable_categories',
    )

    class Meta:
        model = Coupon
        fields = [
            'id',
            'code',
            'scope',
            'vendor',
            'vendor_name',
            'discount_type',
            'discount_value',
            'min_order_amount',
            'applicable_product_ids',
            'applicable_category_ids',
            'created_at',
            'updated_at',
        ]
