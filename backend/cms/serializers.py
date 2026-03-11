from collections import defaultdict

from rest_framework import serializers

from .models import Banner, FAQ, Page, SiteSetting


class SiteSettingPublicSerializer(serializers.ModelSerializer):
    value = serializers.SerializerMethodField()

    class Meta:
        model = SiteSetting
        fields = ['key', 'group', 'setting_type', 'value', 'updated_at']

    def get_value(self, obj):
        request = self.context.get('request')
        value = obj.typed_value
        if obj.setting_type == SiteSetting.SettingType.IMAGE and value and request:
            return request.build_absolute_uri(value)
        return value


class PageIndexSerializer(serializers.ModelSerializer):
    class Meta:
        model = Page
        fields = ['title', 'slug', 'page_type', 'updated_at']


class PageDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = Page
        fields = [
            'title',
            'slug',
            'page_type',
            'content',
            'meta_title',
            'meta_description',
            'updated_at',
        ]


class BannerSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Banner
        fields = [
            'id',
            'title',
            'subtitle',
            'image_url',
            'target_type',
            'target_value',
            'display_order',
            'platform',
            'position',
            'starts_at',
            'ends_at',
            'updated_at',
        ]

    def get_image_url(self, obj):
        request = self.context.get('request')
        if not obj.image:
            return ''
        if request:
            return request.build_absolute_uri(obj.image.url)
        return obj.image.url


class FAQSerializer(serializers.ModelSerializer):
    class Meta:
        model = FAQ
        fields = ['id', 'category', 'question', 'answer', 'display_order', 'updated_at']


class FAQCategorySerializer(serializers.Serializer):
    category = serializers.CharField()
    items = FAQSerializer(many=True)


def serialize_grouped_settings(queryset, context):
    grouped = defaultdict(dict)
    for item in SiteSettingPublicSerializer(queryset, many=True, context=context).data:
        grouped[item['group']][item['key']] = {
            'type': item['setting_type'],
            'value': item['value'],
            'updated_at': item['updated_at'],
        }
    return grouped


def serialize_grouped_faqs(queryset):
    grouped = []
    by_category = defaultdict(list)
    for faq in FAQSerializer(queryset, many=True).data:
        by_category[faq['category']].append(faq)
    for category, items in by_category.items():
        grouped.append({'category': category, 'items': items})
    return grouped

