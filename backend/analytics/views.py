from __future__ import annotations

import time
from typing import Any

from django.db import transaction
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from products.models import Product

from .models import UserEvent
from .serializers import UserEventBatchInSerializer


class UserEventLogView(APIView):
    """
    POST /api/analytics/events/

    Accepts a batch of events. Guests are identified by `session_id` (UUID).
    If an authenticated user has personalization disabled, we skip logging.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        started = time.perf_counter()

        if request.user and request.user.is_authenticated:
            if getattr(request.user, 'personalization_enabled', True) is False:
                return Response(
                    {'ok': True, 'skipped': True, 'created': 0, 'server_ms': 0},
                    status=status.HTTP_200_OK,
                )

        serializer = UserEventBatchInSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        events: list[dict[str, Any]] = serializer.validated_data['events']

        user = request.user if request.user and request.user.is_authenticated else None

        # Guests must send session_id (uuid). For auth users it's optional.
        if user is None and any(e.get('session_id') is None for e in events):
            return Response(
                {'error': 'session_id is required for guest events.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        product_ids = {e.get('product_id') for e in events if e.get('product_id')}
        existing_products = set()
        if product_ids:
            existing_products = set(
                Product.objects.filter(id__in=product_ids).values_list('id', flat=True)
            )

        # Deduplicate within request to reduce spam.
        seen: set[tuple[Any, ...]] = set()
        to_create: list[UserEvent] = []
        for e in events:
            product_id = e.get('product_id')
            if product_id not in existing_products:
                product_id = None

            session_id = e.get('session_id')

            key = (
                e['event_type'],
                e['source'],
                product_id,
                user.id if user else None,
                str(session_id) if session_id else None,
            )
            if key in seen:
                continue
            seen.add(key)

            to_create.append(
                UserEvent(
                    event_type=e['event_type'],
                    source=e['source'],
                    product_id=product_id,
                    user=user,
                    session_id=session_id,
                    metadata=e.get('metadata') or {},
                )
            )

        with transaction.atomic():
            UserEvent.objects.bulk_create(to_create, ignore_conflicts=False)

        server_ms = int((time.perf_counter() - started) * 1000)
        return Response(
            {'ok': True, 'skipped': False, 'created': len(to_create), 'server_ms': server_ms},
            status=status.HTTP_201_CREATED,
        )

# Create your views here.
