from datetime import datetime

from django.core.cache import cache
from django.db.models import Max
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .cache_utils import CMS_BOOTSTRAP_CACHE_KEY, cms_page_cache_key
from .models import Banner, FAQ, Page, SiteSetting
from .serializers import (
    BannerSerializer,
    PageDetailSerializer,
    PageIndexSerializer,
    serialize_grouped_faqs,
    serialize_grouped_settings,
)


def _safe_iso(value):
    if not value:
        return None
    if isinstance(value, str):
        return value
    return value.isoformat()


def _bootstrap_updated_at(now, banners_qs, faq_qs, pages_qs, settings_qs):
    timestamps = [
        banners_qs.aggregate(last=Max('updated_at'))['last'],
        faq_qs.aggregate(last=Max('updated_at'))['last'],
        pages_qs.aggregate(last=Max('updated_at'))['last'],
        settings_qs.aggregate(last=Max('updated_at'))['last'],
    ]
    timestamps = [item for item in timestamps if item]
    return max(timestamps) if timestamps else now


class CmsBootstrapView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        cached = cache.get(CMS_BOOTSTRAP_CACHE_KEY)
        if cached:
            return Response(cached)

        now = timezone.now()
        platform = request.query_params.get('platform', 'ALL').upper()
        banners_qs = Banner.objects.active(now).filter(
            platform__in=[Banner.Platform.ALL, platform]
        )
        settings_qs = SiteSetting.objects.filter(is_public=True)
        pages_qs = Page.objects.filter(is_active=True)
        faq_qs = FAQ.objects.filter(is_active=True)

        payload = {
            'updated_at': _safe_iso(
                _bootstrap_updated_at(now, banners_qs, faq_qs, pages_qs, settings_qs)
            ),
            'banners': {
                'home_top': BannerSerializer(
                    banners_qs.filter(position=Banner.Position.HOME_TOP),
                    many=True,
                    context={'request': request},
                ).data,
                'home_mid': BannerSerializer(
                    banners_qs.filter(position=Banner.Position.HOME_MID),
                    many=True,
                    context={'request': request},
                ).data,
            },
            'site_settings': serialize_grouped_settings(
                settings_qs,
                context={'request': request},
            ),
            'faqs': serialize_grouped_faqs(faq_qs),
            'pages': PageIndexSerializer(pages_qs, many=True).data,
        }
        cache.set(CMS_BOOTSTRAP_CACHE_KEY, payload, timeout=60 * 15)
        return Response(payload)


class CmsPageResolveView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        slug = (request.query_params.get('slug') or '').strip()
        page_type = (request.query_params.get('page_type') or '').strip().upper()

        if not slug and not page_type:
            return Response(
                {'detail': 'Provide either `slug` or `page_type`.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cache_identifier = slug or page_type
        cached = cache.get(cms_page_cache_key(cache_identifier))
        if cached:
            return Response(cached)

        queryset = Page.objects.filter(is_active=True)
        if slug:
            page = queryset.filter(slug=slug).first()
        else:
            page = queryset.filter(page_type=page_type).order_by('title').first()

        if not page:
            return Response({'detail': 'Page not found.'}, status=status.HTTP_404_NOT_FOUND)

        payload = PageDetailSerializer(page).data
        cache.set(cms_page_cache_key(cache_identifier), payload, timeout=60 * 15)
        return Response(payload)

