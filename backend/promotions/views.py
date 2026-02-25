# ═══════════════════════════════════════════════════════════════════
# PROMOTIONS VIEWS
# Single endpoint serving the entire home feed
# ═══════════════════════════════════════════════════════════════════

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.utils import timezone

from .models import Banner, FlashSale, FeaturedSection
from .serializers import BannerSerializer, FlashSaleSerializer, FeaturedSectionSerializer


class HomeFeedView(APIView):
    """
    GET /api/promotions/home-feed/

    Returns the full home page content in a single "typed sections" response.
    Only returns active, time-valid items filtered by platform.

    Query params:
      - platform: ANDROID | IOS (optional, defaults to ALL)
      - locale: en | bn (optional, defaults to en)
    """
    permission_classes = [AllowAny]

    def get(self, request):
        now = timezone.now()
        platform = request.query_params.get('platform', 'ALL').upper()
        locale = request.query_params.get('locale', 'en').lower()

        # ── Fetch active promotions ──────────────────────────────
        banners = Banner.objects.active(now).filter(
            platform__in=['ALL', platform],
            locale__in=['en', locale],  # Always include 'en' as fallback
        ).order_by('-priority', 'starts_at')

        flash_sales = FlashSale.objects.active(now).filter(
            platform__in=['ALL', platform],
            locale__in=['en', locale],
        ).prefetch_related(
            'sale_products__product__vendor',
            'sale_products__product__reviews',
        ).order_by('-priority', 'starts_at')

        featured_sections = FeaturedSection.objects.active(now).filter(
            platform__in=['ALL', platform],
            locale__in=['en', locale],
        ).prefetch_related(
            'products__vendor',
            'products__reviews',
        ).order_by('-priority', 'starts_at')

        # ── Build typed sections list ────────────────────────────
        sections = []

        # Banners section
        banner_data = BannerSerializer(
            banners, many=True, context={'request': request}
        ).data
        if banner_data:
            sections.append({
                'type': 'BANNERS',
                'data': banner_data,
            })

        # Flash sale sections (each sale = one section)
        for sale in flash_sales:
            sale_data = FlashSaleSerializer(
                sale, context={'request': request}
            ).data
            if sale_data.get('products'):
                sections.append({
                    'type': 'FLASH_SALE',
                    'data': sale_data,
                })

        # Featured sections
        for section in featured_sections:
            section_data = FeaturedSectionSerializer(
                section, context={'request': request}
            ).data
            if section_data.get('products'):
                sections.append({
                    'type': 'FEATURED_ROW',
                    'data': section_data,
                })

        return Response({
            'server_now': now.isoformat(),
            'sections': sections,
        })
