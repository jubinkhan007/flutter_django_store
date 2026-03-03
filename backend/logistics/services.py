from __future__ import annotations

import hashlib
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from django.db import transaction
from django.db import models
from django.utils import timezone

from notifications.models import Notification
from notifications.services import NotificationService
from orders.models import Order, ShipmentEvent, SubOrder

from .clients.pathao import PathaoClient, PathaoError
from .clients.redx import RedxClient, RedxError
from .clients.steadfast import SteadfastClient, SteadfastError
from .models import CourierIntegration, LogisticsArea, LogisticsStore


class LogisticsError(Exception):
    pass


def _normalize_courier_code(code: str) -> str:
    return (code or '').strip().lower()


def _courier_enum(code: str) -> str:
    code = _normalize_courier_code(code)
    if code == 'pathao':
        return CourierIntegration.Courier.PATHAO
    if code == 'steadfast':
        return CourierIntegration.Courier.STEADFAST
    if code == 'redx':
        return CourierIntegration.Courier.REDX
    raise LogisticsError('Unsupported courier.')


def _mode_enum(mode: str) -> str:
    mode = (mode or '').upper()
    return CourierIntegration.Mode.PROD if mode == CourierIntegration.Mode.PROD else CourierIntegration.Mode.SANDBOX


def ensure_platform_integration(courier_code: str, *, mode: str) -> CourierIntegration:
    courier = _courier_enum(courier_code)
    mode = _mode_enum(mode)
    integration, _ = CourierIntegration.objects.get_or_create(
        courier=courier,
        owner_type=CourierIntegration.OwnerType.PLATFORM,
        owner_vendor=None,
        mode=mode,
        defaults={'is_enabled': True},
    )
    return integration


def compute_event_hash(courier: str, tracking_number: str, status: str, timestamp: str, location: str) -> str:
    raw = f'{courier}|{tracking_number}|{status}|{timestamp}|{location}'
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()


@dataclass(frozen=True)
class ProvisionResult:
    courier_name: str
    tracking_number: str
    tracking_url: str
    courier_reference_id: str


class LogisticsProvisioningService:
    @staticmethod
    def request_provision(
        sub_order: SubOrder,
        *,
        courier_code: str,
        mode: str,
        request_payload: dict[str, Any],
    ) -> SubOrder:
        sub_order.courier_code = _normalize_courier_code(courier_code)
        sub_order.provision_status = SubOrder.ProvisionStatus.REQUESTED
        sub_order.last_error = ''
        sub_order.provision_request = request_payload or {}
        sub_order.save(update_fields=['courier_code', 'provision_status', 'last_error', 'provision_request', 'updated_at'])
        return sub_order

    @staticmethod
    def provision_suborder(sub_order_id: int, *, mode: str) -> SubOrder:
        mode = _mode_enum(mode)
        sub_order = (
            SubOrder.objects.select_related('order', 'order__delivery_address', 'vendor', 'order__customer')
            .prefetch_related('items')
            .get(id=sub_order_id)
        )

        courier_code = _normalize_courier_code(sub_order.courier_code)
        if not courier_code:
            raise LogisticsError('SubOrder.courier_code is required.')

        integration = ensure_platform_integration(courier_code, mode=mode)
        if not integration.is_enabled:
            raise LogisticsError('Courier integration disabled.')

        try:
            if courier_code == 'pathao':
                result = LogisticsProvisioningService._create_pathao(sub_order, integration)
            elif courier_code == 'steadfast':
                result = LogisticsProvisioningService._create_steadfast(sub_order)
            elif courier_code == 'redx':
                result = LogisticsProvisioningService._create_redx(sub_order, mode=mode)
            else:
                raise LogisticsError('Unsupported courier.')

            # Persist + mark shipped + initial event
            with transaction.atomic():
                sub_order.courier_name = result.courier_name
                sub_order.tracking_number = result.tracking_number
                sub_order.tracking_url = result.tracking_url
                sub_order.courier_reference_id = result.courier_reference_id
                sub_order.provision_status = SubOrder.ProvisionStatus.CREATED
                sub_order.last_error = ''
                sub_order.save(
                    update_fields=[
                        'courier_name',
                        'tracking_number',
                        'tracking_url',
                        'courier_reference_id',
                        'provision_status',
                        'last_error',
                        'updated_at',
                    ]
                )

                # Advance shipment state
                if sub_order.status != Order.Status.SHIPPED:
                    sub_order.advance_status(Order.Status.SHIPPED)

                ShipmentEvent.objects.create(
                    sub_order=sub_order,
                    status=ShipmentEvent.EventStatus.PROCESSING,
                    timestamp=timezone.now(),
                    description=f'Consignment created with {sub_order.courier_name or courier_code}.',
                    source=ShipmentEvent.Source.SYSTEM,
                    created_by=None,
                    sequence=sub_order.events.count(),
                    external_event_id=compute_event_hash(
                        courier=courier_code,
                        tracking_number=sub_order.tracking_number,
                        status='PROCESSING',
                        timestamp=timezone.now().isoformat(),
                        location='',
                    ),
                )

            # Customer notification: ORDER_SHIPPED
            try:
                NotificationService.create(
                    user=sub_order.order.customer,
                    title='Order shipped',
                    body=f'Your order #{sub_order.order.id} has been shipped.',
                    event_type=Notification.Type.ORDER_SHIPPED,
                    category=Notification.Category.TRANSACTIONAL,
                    deeplink=f'app://orders/{sub_order.order.id}?sub_id={sub_order.id}',
                    data={
                        'order_id': str(sub_order.order.id),
                        'suborder_id': str(sub_order.id),
                        'status': 'SHIPPED',
                    },
                    inbox_visible=True,
                    push_enabled=True,
                )
            except Exception:
                pass

            return sub_order
        except Exception as e:
            sub_order.provision_status = SubOrder.ProvisionStatus.FAILED
            sub_order.last_error = str(e)
            sub_order.save(update_fields=['provision_status', 'last_error', 'updated_at'])
            return sub_order

    @staticmethod
    def _cod_amount(sub_order: SubOrder) -> Decimal:
        total = Decimal('0.00')
        for item in sub_order.items.all():
            try:
                total += item.total_price
            except Exception:
                total += (item.unit_price or Decimal('0.00')) * item.quantity
        return total.quantize(Decimal('0.01'))

    @staticmethod
    def _create_steadfast(sub_order: SubOrder) -> ProvisionResult:
        client = SteadfastClient()
        addr = sub_order.order.delivery_address
        if not addr:
            raise LogisticsError('Delivery address missing.')

        invoice = f'ORD-{sub_order.order_id}-SUB-{sub_order.id}'
        cod_amount = LogisticsProvisioningService._cod_amount(sub_order) if sub_order.order.payment_method == Order.PaymentMethod.COD else Decimal('0.00')
        payload = {
            'invoice': invoice,
            'recipient_name': sub_order.order.customer.username or 'Customer',
            'recipient_phone': addr.phone_number,
            'recipient_address': f'{addr.address_line}, {addr.area}, {addr.city}',
            'cod_amount': float(cod_amount),
        }
        resp = client.create_order(payload)
        data = resp.get('consignment') or resp.get('data') or resp
        consignment_id = str(data.get('consignment_id') or data.get('id') or '')
        tracking = str(data.get('tracking_code') or data.get('tracking') or consignment_id)
        if not consignment_id:
            raise SteadfastError('Missing consignment_id in response.')

        return ProvisionResult(
            courier_name='Steadfast',
            tracking_number=tracking,
            tracking_url='https://portal.packzy.com/track/',
            courier_reference_id=consignment_id,
        )

    @staticmethod
    def _create_pathao(sub_order: SubOrder, integration: CourierIntegration) -> ProvisionResult:
        client = PathaoClient(integration)
        addr = sub_order.order.delivery_address
        if not addr:
            raise LogisticsError('Delivery address missing.')

        req = sub_order.provision_request or {}
        store_id = req.get('store_id')
        recipient_city = req.get('recipient_city')
        recipient_zone = req.get('recipient_zone')
        recipient_area = req.get('recipient_area')
        item_weight = req.get('item_weight')
        item_type = req.get('item_type') or 2  # 2=parcel (common default)
        delivery_type = req.get('delivery_type') or 48  # 48=normal delivery (per docs)

        if not all([store_id, recipient_city, recipient_zone, recipient_area, item_weight]):
            raise LogisticsError('Missing Pathao provisioning fields (store_id/city/zone/area/item_weight).')

        cod_amount = LogisticsProvisioningService._cod_amount(sub_order) if sub_order.order.payment_method == Order.PaymentMethod.COD else Decimal('0.00')
        item_quantity = sum([it.quantity for it in sub_order.items.all()])

        payload = {
            'store_id': int(store_id),
            'merchant_order_id': f'ORD-{sub_order.order_id}-SUB-{sub_order.id}',
            'recipient_name': sub_order.order.customer.username or 'Customer',
            'recipient_phone': addr.phone_number,
            'recipient_address': f'{addr.address_line}, {addr.area}, {addr.city}',
            'recipient_city': int(recipient_city),
            'recipient_zone': int(recipient_zone),
            'recipient_area': int(recipient_area),
            'delivery_type': int(delivery_type),
            'item_type': int(item_type),
            'item_quantity': int(item_quantity),
            'item_weight': float(item_weight),
            'amount_to_collect': float(cod_amount),
            'special_instruction': (req.get('special_instruction') or '').strip(),
        }

        created = client.create_order(payload)
        consignment_id = str(created.get('consignment_id') or created.get('consignmentId') or '')
        tracking_url = created.get('tracking_url') or created.get('trackingUrl') or ''
        if not consignment_id:
            raise PathaoError('Missing consignment_id in response.')
        if not tracking_url:
            tracking_url = f'{client.creds.base_url}/aladdin/api/v1/order/info?consignment_id={consignment_id}'

        return ProvisionResult(
            courier_name='Pathao',
            tracking_number=consignment_id,
            tracking_url=tracking_url,
            courier_reference_id=consignment_id,
        )

    @staticmethod
    def _create_redx(sub_order: SubOrder, *, mode: str) -> ProvisionResult:
        client = RedxClient(mode=mode)
        req = sub_order.provision_request or {}
        addr = sub_order.order.delivery_address
        if not addr:
            raise LogisticsError('Delivery address missing.')

        payload = {
            'merchant_order_id': f'ORD-{sub_order.order_id}-SUB-{sub_order.id}',
            'recipient_name': sub_order.order.customer.username or 'Customer',
            'recipient_phone': addr.phone_number,
            'recipient_address': f'{addr.address_line}, {addr.area}, {addr.city}',
            **req,
        }
        created = client.create_parcel(payload)
        data = created.get('data') if isinstance(created, dict) else created
        if isinstance(data, dict):
            reference = str(data.get('tracking_id') or data.get('tracking_number') or data.get('parcel_id') or '')
            tracking_url = str(data.get('tracking_url') or '')
        else:
            reference = ''
            tracking_url = ''
        if not reference:
            # Try a common key fallback
            reference = str(created.get('tracking_id') or created.get('tracking_number') or created.get('parcel_id') or '')
        if not reference:
            raise RedxError('Missing tracking reference in response.')
        return ProvisionResult(
            courier_name='RedX',
            tracking_number=reference,
            tracking_url=tracking_url,
            courier_reference_id=reference,
        )


class LogisticsAreaService:
    @staticmethod
    def _upsert(
        *,
        courier: str,
        mode: str,
        kind: str,
        external_id: str,
        name: str,
        parent: LogisticsArea | None,
        raw: dict[str, Any],
    ) -> LogisticsArea:
        obj, _ = LogisticsArea.objects.update_or_create(
            courier=courier,
            mode=mode,
            kind=kind,
            external_id=str(external_id),
            defaults={
                'name': name,
                'parent': parent,
                'raw': raw or {},
                'last_synced_at': timezone.now(),
            },
        )
        return obj

    @staticmethod
    def sync_pathao_cities(integration: CourierIntegration) -> list[LogisticsArea]:
        client = PathaoClient(integration)
        courier = CourierIntegration.Courier.PATHAO
        mode = integration.mode
        out: list[LogisticsArea] = []
        for c in client.list_cities():
            out.append(
                LogisticsAreaService._upsert(
                    courier=courier,
                    mode=mode,
                    kind=LogisticsArea.Kind.CITY,
                    external_id=str(c.get('city_id') or c.get('id')),
                    name=str(c.get('city_name') or c.get('name') or ''),
                    parent=None,
                    raw=c,
                )
            )
        return out

    @staticmethod
    def sync_pathao_zones(integration: CourierIntegration, *, city_external_id: str) -> list[LogisticsArea]:
        client = PathaoClient(integration)
        courier = CourierIntegration.Courier.PATHAO
        mode = integration.mode
        city = LogisticsArea.objects.filter(
            courier=courier, mode=mode, kind=LogisticsArea.Kind.CITY, external_id=str(city_external_id)
        ).first()
        if not city:
            # Best-effort: sync cities then retry.
            LogisticsAreaService.sync_pathao_cities(integration)
            city = LogisticsArea.objects.filter(
                courier=courier, mode=mode, kind=LogisticsArea.Kind.CITY, external_id=str(city_external_id)
            ).first()
        if not city:
            raise LogisticsError('City not found.')
        out: list[LogisticsArea] = []
        for z in client.list_zones(int(city.external_id)):
            out.append(
                LogisticsAreaService._upsert(
                    courier=courier,
                    mode=mode,
                    kind=LogisticsArea.Kind.ZONE,
                    external_id=str(z.get('zone_id') or z.get('id')),
                    name=str(z.get('zone_name') or z.get('name') or ''),
                    parent=city,
                    raw=z,
                )
            )
        return out

    @staticmethod
    def sync_pathao_areas(integration: CourierIntegration, *, zone_external_id: str) -> list[LogisticsArea]:
        client = PathaoClient(integration)
        courier = CourierIntegration.Courier.PATHAO
        mode = integration.mode
        zone = LogisticsArea.objects.filter(
            courier=courier, mode=mode, kind=LogisticsArea.Kind.ZONE, external_id=str(zone_external_id)
        ).first()
        if not zone:
            raise LogisticsError('Zone not found.')
        out: list[LogisticsArea] = []
        for a in client.list_areas(int(zone.external_id)):
            out.append(
                LogisticsAreaService._upsert(
                    courier=courier,
                    mode=mode,
                    kind=LogisticsArea.Kind.AREA,
                    external_id=str(a.get('area_id') or a.get('id')),
                    name=str(a.get('area_name') or a.get('name') or ''),
                    parent=zone,
                    raw=a,
                )
            )
        return out


class LogisticsStoreService:
    @staticmethod
    def list_vendor_stores(*, vendor, courier: str | None = None, mode: str | None = None):
        qs = LogisticsStore.objects.filter(is_active=True)
        if courier:
            qs = qs.filter(courier=courier)
        if mode:
            qs = qs.filter(mode=mode)
        # Platform stores OR explicitly assigned to the vendor.
        return qs.filter(models.Q(owner_type=LogisticsStore.OwnerType.PLATFORM) | models.Q(assigned_vendors=vendor)).distinct()
