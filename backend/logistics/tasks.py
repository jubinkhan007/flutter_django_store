from __future__ import annotations

from celery import shared_task
from django.conf import settings

from orders.models import Order, ShipmentEvent, SubOrder

from .clients.pathao import PathaoError, PathaoClient
from .clients.redx import RedxError, RedxClient
from .clients.steadfast import SteadfastError, SteadfastClient
from .models import CourierIntegration
from .services import LogisticsProvisioningService, compute_event_hash, ensure_platform_integration


@shared_task
def provision_suborder_task(sub_order_id: int, mode: str = 'SANDBOX') -> int:
    updated = LogisticsProvisioningService.provision_suborder(sub_order_id, mode=mode)
    return updated.id


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


@shared_task
def poll_courier_updates_task(mode: str = 'SANDBOX') -> int:
    """
    Fallback polling for couriers where webhooks are unreliable/unavailable.
    Runs every 30 minutes (configured in CELERY_BEAT_SCHEDULE).
    """
    mode = (mode or 'SANDBOX').upper()
    qs = SubOrder.objects.exclude(status__in=[Order.Status.CANCELED, Order.Status.DELIVERED]).filter(
        provision_status=SubOrder.ProvisionStatus.CREATED
    )
    updated = 0

    for so in qs.iterator():
        code = (so.courier_code or '').strip().lower()
        if not code:
            continue

        try:
            if code == 'steadfast':
                if not so.courier_reference_id:
                    continue
                client = SteadfastClient()
                data = client.status_by_consignment_id(so.courier_reference_id)
                st = (data.get('delivery_status') or data.get('status') or '').strip()
                desc = data.get('message') or data.get('status_message') or st
                ts = data.get('updated_at') or data.get('date') or ''
                status = _map_status(st)
                ext_id = compute_event_hash('steadfast', so.tracking_number or so.courier_reference_id, status, ts, '')
                ShipmentEvent.objects.get_or_create(
                    sub_order=so,
                    external_event_id=ext_id,
                    defaults={
                        'status': status,
                        'location': '',
                        'timestamp': so.updated_at,
                        'description': str(desc)[:5000],
                        'sequence': so.events.count(),
                        'source': ShipmentEvent.Source.POLLING,
                        'created_by': None,
                    },
                )
                updated += 1
            elif code == 'pathao':
                if not so.courier_reference_id:
                    continue
                integration = ensure_platform_integration('pathao', mode=mode)
                client = PathaoClient(integration)
                info = client.order_info(so.courier_reference_id)
                st = str(info.get('order_status') or info.get('status') or '')
                desc = info.get('status_message') or info.get('message') or st
                ts = str(info.get('updated_at') or info.get('updatedAt') or '')
                status = _map_status(st)
                ext_id = compute_event_hash('pathao', so.courier_reference_id, status, ts, '')
                ShipmentEvent.objects.get_or_create(
                    sub_order=so,
                    external_event_id=ext_id,
                    defaults={
                        'status': status,
                        'location': '',
                        'timestamp': so.updated_at,
                        'description': str(desc)[:5000],
                        'sequence': so.events.count(),
                        'source': ShipmentEvent.Source.POLLING,
                        'created_by': None,
                    },
                )
                updated += 1
            elif code == 'redx':
                if not so.courier_reference_id:
                    continue
                client = RedxClient(mode=mode)
                info = client.parcel_status(so.courier_reference_id)
                st = str(info.get('status') or info.get('delivery_status') or '')
                desc = info.get('message') or info.get('status_message') or st
                ts = str(info.get('updated_at') or info.get('date') or '')
                status = _map_status(st)
                ext_id = compute_event_hash('redx', so.courier_reference_id, status, ts, '')
                ShipmentEvent.objects.get_or_create(
                    sub_order=so,
                    external_event_id=ext_id,
                    defaults={
                        'status': status,
                        'location': '',
                        'timestamp': so.updated_at,
                        'description': str(desc)[:5000],
                        'sequence': so.events.count(),
                        'source': ShipmentEvent.Source.POLLING,
                        'created_by': None,
                    },
                )
                updated += 1
        except (SteadfastError, PathaoError, RedxError):
            continue
        except Exception:
            continue

    return updated

