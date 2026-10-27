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


class DeliveryEstimateView(generics.GenericAPIView):
    """
    GET /api/logistics/estimate/?product_id=<id>&city=<city>&area=<area>&variant_id=<id>&quantity=<int>
    Calculates estimated delivery fees and date windows on the PDP.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, *args, **kwargs):
        product_id = request.query_params.get('product_id')
        if not product_id:
            return Response(
                {'error': 'product_id query parameter is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from products.models import Product
        try:
            product = (
                Product.objects.select_related('vendor', 'category')
                .prefetch_related('vendor__logistics_stores')
                .get(pk=product_id)
            )
        except Product.DoesNotExist:
            return Response({'error': 'Product not found.'}, status=status.HTTP_404_NOT_FOUND)

        city = request.query_params.get('city')
        area = request.query_params.get('area')

        # Fallback to logged-in customer's default saved address if location omitted
        if not city and request.user.is_authenticated:
            from users.models import Address
            user_addr = (
                Address.objects.filter(user=request.user, is_default=True).first()
                or Address.objects.filter(user=request.user).first()
            )
            if user_addr:
                city = user_addr.city
                if not area:
                    area = user_addr.area

        # Fallback defaults to Dhaka
        if not city:
            city = 'Dhaka'

        variant_id = request.query_params.get('variant_id')
        variant = None
        if variant_id:
            variant = product.variants.filter(pk=variant_id).first()

        try:
            quantity = int(request.query_params.get('quantity', 1))
        except (ValueError, TypeError):
            quantity = 1

        from .estimate_service import DeliveryEstimateService
        estimate = DeliveryEstimateService.calculate_estimate(
            product=product,
            destination_city=city,
            destination_area=area,
            quantity=quantity,
            variant=variant,
        )

        return Response(estimate)


class LiveDeliveryTrackingDetailView(generics.GenericAPIView):
    """
    GET /api/logistics/sub-orders/<sub_order_id>/live-tracking/
    Fetch or initialize live delivery tracking with rider GPS, ETA, and route waypoints.
    Supports auto-advancing simulation when polled.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, sub_order_id, *args, **kwargs):
        try:
            sub_order = SubOrder.objects.select_related('order', 'order__customer', 'vendor', 'order__delivery_address').get(id=sub_order_id)
        except SubOrder.DoesNotExist:
            return Response({'error': 'Sub-order not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Access check: customer of order, vendor owner/staff, or superuser
        user = request.user
        is_customer = (sub_order.order.customer_id == user.id)
        is_vendor = (sub_order.vendor and sub_order.vendor.user_id == user.id)
        is_staff = user.is_staff or user.is_superuser
        if not (is_customer or is_vendor or is_staff):
            return Response({'error': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

        from .models import LiveDeliveryTracking
        from .serializers import LiveDeliveryTrackingSerializer

        tracking = getattr(sub_order, 'live_tracking', None)
        if not tracking:
            # Auto-provision realistic coordinates based on customer delivery address
            dest_name = 'Customer Delivery Address'
            dest_lat = 23.8103
            dest_lng = 90.4125
            if sub_order.order.delivery_address:
                addr = sub_order.order.delivery_address
                dest_name = f"{addr.address_line}, {addr.area}, {addr.city}"
                area_l = (addr.area or '').lower()
                if 'dhanmondi' in area_l:
                    dest_lat, dest_lng = 23.7465, 90.3760
                elif 'uttara' in area_l:
                    dest_lat, dest_lng = 23.8759, 90.3795
                elif 'mirpur' in area_l:
                    dest_lat, dest_lng = 23.8071, 90.3686
                elif 'banani' in area_l:
                    dest_lat, dest_lng = 23.7937, 90.4046
                elif 'gulshan' in area_l:
                    dest_lat, dest_lng = 23.7925, 90.4150
                elif 'baridhara' in area_l:
                    dest_lat, dest_lng = 23.8050, 90.4200
                elif 'chattogram' in (addr.city or '').lower():
                    dest_lat, dest_lng = 22.3569, 91.7832

            origin_name = f"{sub_order.vendor.store_name} Fulfillment Hub" if sub_order.vendor else "Merchant Dispatch Hub"
            origin_lat = 23.7749
            origin_lng = 90.4043

            courier_brand = sub_order.courier_name or 'Pathao Express'
            tracking = LiveDeliveryTracking.objects.create(
                sub_order=sub_order,
                rider_name='Tanvir Ahmed',
                rider_phone='+8801712345678',
                rider_rating=4.9,
                vehicle_type='Motorcycle',
                vehicle_number='DHAKA METRO-HA-12-3456',
                courier_brand=courier_brand,
                status=LiveDeliveryTracking.DispatchStatus.OUT_FOR_DELIVERY,
                origin_latitude=origin_lat,
                origin_longitude=origin_lng,
                origin_name=origin_name,
                destination_latitude=dest_lat,
                destination_longitude=dest_lng,
                destination_name=dest_name,
                current_latitude=origin_lat + 0.005,
                current_longitude=origin_lng + 0.003,
                eta_minutes=14,
                distance_km=2.10,
                heading_degrees=42.0,
                speed_kmh=24.0,
                current_waypoint_index=3,
            )
            tracking.ensure_route_waypoints()
            tracking.save()

        # Check simulation advance parameter or periodic progression
        should_advance = request.query_params.get('advance') == 'true'
        now = timezone.now()
        if not should_advance and tracking.status != LiveDeliveryTracking.DispatchStatus.DELIVERED:
            # Advance step if at least 8 seconds elapsed since last update
            if (now - tracking.last_location_update).total_seconds() >= 8:
                should_advance = True

        if should_advance and tracking.status != LiveDeliveryTracking.DispatchStatus.DELIVERED:
            tracking.advance_simulation(steps=1)

        serializer = LiveDeliveryTrackingSerializer(tracking)
        return Response(serializer.data)


class LiveDeliveryLocationUpdateView(generics.GenericAPIView):
    """
    POST /api/logistics/sub-orders/<sub_order_id>/update-location/
    Vendor, Rider, or Admin pushes real-time GPS coordinate updates.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, sub_order_id, *args, **kwargs):
        try:
            sub_order = SubOrder.objects.get(id=sub_order_id)
        except SubOrder.DoesNotExist:
            return Response({'error': 'Sub-order not found.'}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        is_vendor = (sub_order.vendor and sub_order.vendor.user_id == user.id)
        is_staff = user.is_staff or user.is_superuser
        if not (is_vendor or is_staff):
            return Response({'error': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

        from .models import LiveDeliveryTracking
        from .serializers import LiveDeliveryTrackingSerializer

        tracking, _ = LiveDeliveryTracking.objects.get_or_create(sub_order=sub_order)

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        if lat is not None:
            tracking.current_latitude = float(lat)
        if lng is not None:
            tracking.current_longitude = float(lng)

        if 'status' in request.data:
            st = request.data['status'].upper()
            if st in LiveDeliveryTracking.DispatchStatus.values:
                tracking.status = st
        if 'speed_kmh' in request.data:
            tracking.speed_kmh = float(request.data['speed_kmh'])
        if 'heading_degrees' in request.data:
            tracking.heading_degrees = float(request.data['heading_degrees'])
        if 'eta_minutes' in request.data:
            tracking.eta_minutes = int(request.data['eta_minutes'])
        if 'distance_km' in request.data:
            from decimal import Decimal
            tracking.distance_km = Decimal(str(request.data['distance_km']))
        if 'rider_name' in request.data:
            tracking.rider_name = request.data['rider_name']
        if 'rider_phone' in request.data:
            tracking.rider_phone = request.data['rider_phone']

        tracking.save()
        return Response(LiveDeliveryTrackingSerializer(tracking).data)

