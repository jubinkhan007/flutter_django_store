from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from notifications.models import Notification
from notifications.services import NotificationService

from .models import Ticket, TicketMessage


def _snapshot_for_return(rr) -> dict:
    items = []
    for it in rr.items.select_related('order_item', 'order_item__product').all():
        oi = it.order_item
        product = getattr(oi, 'product', None)
        items.append(
            {
                'order_item_id': oi.id,
                'product_id': getattr(product, 'id', None),
                'product_title': getattr(oi, 'product_title', '') or getattr(product, 'name', ''),
                'quantity': it.quantity,
                'unit_price': str(getattr(oi, 'unit_price', '0.00')),
                'condition': it.condition,
            }
        )

    images = [img.image.url for img in rr.images.all()]

    return {
        'return_request_id': rr.id,
        'rma_number': rr.rma_number,
        'status': rr.status,
        'reason': rr.reason,
        'reason_details': rr.reason_details,
        'request_type': rr.request_type,
        'refund_method_preference': rr.refund_method_preference,
        'vendor_note': rr.vendor_note,
        'customer_note': rr.customer_note,
        'items': items,
        'images': images,
        'order_id': rr.order_id,
        'vendor_id': rr.vendor_id,
        'created_at': rr.created_at.isoformat() if rr.created_at else '',
    }


class SupportService:
    @staticmethod
    def ensure_dispute_ticket_for_return(rr) -> Ticket:
        """
        Creates (or returns) a ticket for an escalated return request.
        """
        existing = Ticket.objects.filter(return_request=rr).order_by('-created_at').first()
        if existing:
            return existing

        with transaction.atomic():
            ticket = Ticket.objects.create(
                subject=f'Dispute for {rr.rma_number}',
                category=Ticket.Category.ORDER,
                order=rr.order,
                sub_order=None,
                return_request=rr,
                vendor=rr.vendor,
                customer=rr.customer,
                status=Ticket.Status.OPEN,
                context_snapshot=_snapshot_for_return(rr),
                last_activity_at=timezone.now(),
            )
            TicketMessage.objects.create(
                ticket=ticket,
                sender=None,
                kind=TicketMessage.Kind.SYSTEM_EVENT,
                text='Return escalated to dispute.',
                is_internal_note=False,
            )

            def _notify() -> None:
                # Admin/support notification: TICKET_CREATED + DISPUTE_ESCALATED
                try:
                    from django.contrib.auth import get_user_model

                    User = get_user_model()
                    admins = User.objects.filter(type=User.Types.ADMIN)
                    for admin_user in admins:
                        NotificationService.create(
                            user=admin_user,
                            title='Dispute escalated',
                            body=f'{rr.rma_number} escalated to support.',
                            event_type=Notification.Type.DISPUTE_ESCALATED,
                            category=Notification.Category.TRANSACTIONAL,
                            deeplink=f'app://support/tickets/{ticket.id}',
                            data={'ticket_id': str(ticket.id), 'return_request_id': str(rr.id)},
                            inbox_visible=True,
                            push_enabled=True,
                        )
                except Exception:
                    pass

                # Vendor notification
                try:
                    NotificationService.create(
                        user=rr.vendor.user,
                        title='Dispute opened',
                        body=f'A dispute has been opened for {rr.rma_number}.',
                        event_type=Notification.Type.DISPUTE_ESCALATED,
                        category=Notification.Category.TRANSACTIONAL,
                        deeplink=f'app://support/tickets/{ticket.id}',
                        data={'ticket_id': str(ticket.id), 'return_request_id': str(rr.id)},
                        inbox_visible=True,
                        push_enabled=True,
                    )
                except Exception:
                    pass

            transaction.on_commit(_notify)

            return ticket
