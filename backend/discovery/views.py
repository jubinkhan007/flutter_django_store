from __future__ import annotations

import uuid

from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from products.models import Product

from .models import Collection
from .serializers import (
    CollectionPreviewSerializer,
    DiscoveryHomeSerializer,
    ProductRecommendationsSerializer,
)
from .services import RecommendationService
from promotions.serializers import CompactProductSerializer


class DiscoveryHomeView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, *args, **kwargs):
        session_id_raw = request.query_params.get('session_id')
        session_id = None
        if session_id_raw:
            try:
                session_id = uuid.UUID(str(session_id_raw))
            except Exception:
                session_id = None

        svc = RecommendationService(user=request.user, session_id=session_id)
        payload = svc.home_payload()

        data = {
            'server_now': timezone.now().isoformat(),
            'recently_viewed': payload['recently_viewed'],
            'recommended': payload['recommended'],
            'trending': payload['trending'],
            'collections': payload['collections'],
        }

        return Response(DiscoveryHomeSerializer(data, context={'request': request}).data)


class ProductRecommendationsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, product_id: int, *args, **kwargs):
        get_object_or_404(Product, id=product_id)

        session_id_raw = request.query_params.get('session_id')
        session_id = None
        if session_id_raw:
            try:
                session_id = uuid.UUID(str(session_id_raw))
            except Exception:
                session_id = None

        svc = RecommendationService(user=request.user, session_id=session_id)
        payload = svc.recommendations_for_product(product_id, limit=12)
        return Response(ProductRecommendationsSerializer(payload, context={'request': request}).data)


class CollectionDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, slug: str, *args, **kwargs):
        now = timezone.now()
        collection = get_object_or_404(
            Collection.objects.filter(is_active=True),
            slug=slug,
        )

        if collection.starts_at and collection.starts_at > now:
            return Response({'error': 'Not active.'}, status=404)
        if collection.ends_at and collection.ends_at < now:
            return Response({'error': 'Not active.'}, status=404)

        product_ids = list(
            collection.items.order_by('sort_order').values_list('product_id', flat=True)
        )
        products = list(Product.objects.filter(id__in=product_ids, is_available=True).select_related('vendor', 'category'))
        by_id = {p.id: p for p in products}
        ordered_products = [by_id[pid] for pid in product_ids if pid in by_id]
        in_stock = [p for p in ordered_products if (p.stock_quantity or 0) > 0]
        oos = [p for p in ordered_products if p not in in_stock]
        gated_products = in_stock + oos

        return Response(
            {
                'collection': CollectionPreviewSerializer(collection, context={'request': request}).data,
                'products': CompactProductSerializer(
                    gated_products,
                    many=True,
                    context={'request': request},
                ).data,
            }
        )
