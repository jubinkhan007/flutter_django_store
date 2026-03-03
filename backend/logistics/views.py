from __future__ import annotations

import os
from typing import Any

from django.db import IntegrityError
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from vendors.permissions import IsVendorSupportOrAbove
from orders.models import ShipmentEvent, SubOrder

from .models import CourierIntegration, LogisticsArea, LogisticsStore
from .serializers import LogisticsAreaSerializer, LogisticsStoreSerializer
from .clients.pathao import PathaoClient
from .services import (
    LogisticsAreaService,
    LogisticsError,
    LogisticsProvisioningService,
    compute_event_hash,
    ensure_platform_integration,
)
from .tasks import provision_suborder_task


def _map_status(raw: str) -> str:
    s = (raw or '').strip().lower()
    if not s:
        return ShipmentEvent.EventStatus.PROCESSING
    if 'deliver' in s:
        return ShipmentEvent.EventStatus.DELIVERED
    if 'cancel' in s:
        return ShipmentEvent.EventStatus.CANCELLED
    if 'return' in s:
        return ShipmentEvent.EventStatus.RETURNED
    if 'out' in s and 'deliver' in s:
        return ShipmentEvent.EventStatus.OUT_FOR_DELIVERY
    if 'transit' in s:
        return ShipmentEvent.EventStatus.IN_TRANSIT
    if 'pickup' in s or 'picked' in s:
        return ShipmentEvent.EventStatus.PICKED_UP
    if 'packed' in s:
        return ShipmentEvent.EventStatus.PACKED
    return ShipmentEvent.EventStatus.PROCESSING


class VendorLogisticsStoreListView(generics.ListAPIView):
    permission_classes = [IsVendorSupportOrAbove]
    serializer_class = LogisticsStoreSerializer

    def get_queryset(self):
        courier = self.request.query_params.get('courier')
        mode = (self.request.query_params.get('mode') or '').upper()
        qs = LogisticsStore.objects.filter(is_active=True)
        if courier:
            qs = qs.filter(courier=courier.upper())
        if mode in (LogisticsStore.Mode.SANDBOX, LogisticsStore.Mode.PROD):
            qs = qs.filter(mode=mode)
        return qs.filter(
            Q(owner_type=LogisticsStore.OwnerType.PLATFORM)
            | Q(owner_vendor=self.request.vendor)
            | Q(assigned_vendors=self.request.vendor)
        ).distinct()


class PathaoCityListView(generics.GenericAPIView):
    permission_classes = [IsVendorSupportOrAbove]

    def get(self, request, *args, **kwargs):
        mode = (request.query_params.get('mode') or CourierIntegration.Mode.SANDBOX).upper()
        integration = ensure_platform_integration('pathao', mode=mode)
        try:
            cities = LogisticsAreaService.sync_pathao_cities(integration)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LogisticsAreaSerializer(cities, many=True).data)


class PathaoZoneListView(generics.GenericAPIView):
    permission_classes = [IsVendorSupportOrAbove]

    def get(self, request, *args, **kwargs):
        mode = (request.query_params.get('mode') or CourierIntegration.Mode.SANDBOX).upper()
        city_id = request.query_params.get('city_id')
        if not city_id:
            return Response({'error': 'city_id is required.'}, status=status.HTTP_400_BAD_REQUEST)
        integration = ensure_platform_integration('pathao', mode=mode)
        try:
            zones = LogisticsAreaService.sync_pathao_zones(integration, city_external_id=str(city_id))
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LogisticsAreaSerializer(zones, many=True).data)


class PathaoAreaListView(generics.GenericAPIView):
    permission_classes = [IsVendorSupportOrAbove]

    def get(self, request, *args, **kwargs):
        mode = (request.query_params.get('mode') or CourierIntegration.Mode.SANDBOX).upper()
        zone_id = request.query_params.get('zone_id')
        if not zone_id:
            return Response({'error': 'zone_id is required.'}, status=status.HTTP_400_BAD_REQUEST)
        integration = ensure_platform_integration('pathao', mode=mode)
        try:
            areas = LogisticsAreaService.sync_pathao_areas(integration, zone_external_id=str(zone_id))
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(LogisticsAreaSerializer(areas, many=True).data)


class PathaoStoreListView(generics.GenericAPIView):
    permission_classes = [IsVendorSupportOrAbove]

    def get(self, request, *args, **kwargs):
        mode = (request.query_params.get('mode') or CourierIntegration.Mode.SANDBOX).upper()
        integration = ensure_platform_integration('pathao', mode=mode)
        try:
            client = PathaoClient(integration)
            stores = client.list_stores()
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        out = []
        for s in stores:
            ext_id = str(s.get('store_id') or s.get('id') or '')
            name = str(s.get('store_name') or s.get('name') or '')
            if not ext_id:
                continue
            obj, _ = LogisticsStore.objects.update_or_create(
                courier=CourierIntegration.Courier.PATHAO,
                mode=mode,
                external_store_id=ext_id,
                defaults={
                    'owner_type': LogisticsStore.OwnerType.PLATFORM,
                    'owner_vendor': None,
                    'name': name or f'Pathao store {ext_id}',
                    'contact_name': str(s.get('contact_name') or ''),
                    'phone': str(s.get('contact_number') or s.get('phone') or ''),
                    'address': str(s.get('address') or ''),
                    'city': str(s.get('city_name') or ''),
                    'area': str(s.get('area_name') or ''),
                    'is_active': True,
                },
            )
            out.append(obj)
        return Response(LogisticsStoreSerializer(out, many=True).data)


class LogisticsAreaSearchView(generics.GenericAPIView):
    permission_classes = [IsVendorSupportOrAbove]

    def get(self, request, courier: str, *args, **kwargs):
        q = (request.query_params.get('q') or '').strip()
        if not q:
            return Response([])
        mode = (request.query_params.get('mode') or CourierIntegration.Mode.SANDBOX).upper()
        qs = LogisticsArea.objects.filter(
            courier=courier.upper(),
            mode=mode,
            kind=LogisticsArea.Kind.AREA,
            name__icontains=q,
        ).order_by('name')[:50]
        return Response(LogisticsAreaSerializer(qs, many=True).data)


class VendorRetryProvisionView(generics.GenericAPIView):
    permission_classes = [IsVendorSupportOrAbove]

    def post(self, request, sub_order_id: int, *args, **kwargs):
        try:
            so = SubOrder.objects.filter(vendor=request.vendor).get(id=sub_order_id)
        except SubOrder.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        mode = (request.data.get('mode') or CourierIntegration.Mode.SANDBOX).upper()
        so.provision_status = SubOrder.ProvisionStatus.REQUESTED
        so.last_error = ''
        so.save(update_fields=['provision_status', 'last_error', 'updated_at'])
        provision_suborder_task.delay(so.id, mode=mode)
        return Response({'ok': True})


class LogisticsWebhookView(generics.GenericAPIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, courier: str, *args, **kwargs):
        secret = os.getenv('LOGISTICS_WEBHOOK_SECRET', '').strip()
        if secret:
            incoming = (request.headers.get('X-Webhook-Secret') or '').strip()
            if incoming != secret:
                return Response({'error': 'Unauthorized.'}, status=status.HTTP_401_UNAUTHORIZED)

        payload = request.data if isinstance(request.data, dict) else {}
        tracking_number = str(payload.get('tracking_number') or payload.get('tracking') or payload.get('consignment_id') or '')
        status_raw = str(payload.get('status') or payload.get('delivery_status') or payload.get('order_status') or '')
        location = str(payload.get('location') or payload.get('hub') or '')
        description = str(payload.get('message') or payload.get('status_message') or '')
        timestamp = str(payload.get('timestamp') or payload.get('updated_at') or timezone.now().isoformat())
        external_event_id = str(payload.get('external_event_id') or payload.get('event_id') or '')

        if not tracking_number:
            return Response({'error': 'tracking_number is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            so = SubOrder.objects.get(tracking_number=tracking_number)
        except SubOrder.DoesNotExist:
            return Response({'ok': True})

        if not external_event_id:
            external_event_id = compute_event_hash(
                courier=courier,
                tracking_number=tracking_number,
                status=status_raw,
                timestamp=timestamp,
                location=location,
            )

        try:
            ev, created = ShipmentEvent.objects.get_or_create(
                sub_order=so,
                external_event_id=external_event_id,
                defaults={
                    'status': _map_status(status_raw),
                    'location': location,
                    'timestamp': timezone.now(),
                    'description': description or status_raw,
                    'sequence': so.events.count(),
                    'source': ShipmentEvent.Source.WEBHOOK,
                    'created_by': None,
                },
            )
            return Response({'ok': True, 'created': created})
        except IntegrityError:
            return Response({'ok': True, 'created': False})
