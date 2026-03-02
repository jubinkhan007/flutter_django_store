from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from django.contrib.auth import get_user_model
from django.db import transaction

from .models import Notification


User = get_user_model()


def _group_type(event_type: str) -> str:
    if event_type.startswith('ORDER_') or event_type == Notification.Type.NEW_SUBORDER:
        return 'ORDER'
    if event_type.startswith('PAYOUT_'):
        return 'PAYOUT'
    if event_type.startswith('REFUND_'):
        return 'REFUND'
    if event_type.startswith('TICKET_') or event_type.startswith('DISPUTE_'):
        return 'SUPPORT'
    if event_type == Notification.Type.PROMOTION:
        return 'PROMO'
    return 'GENERAL'


@dataclass(frozen=True)
class NotificationPayload:
    title: str
    body: str
    type: str
    event: str
    category: str
    deeplink: str
    data: dict[str, Any]


class NotificationService:
    @staticmethod
    def create(
        *,
        user: User,
        title: str,
        body: str,
        event_type: str,
        category: str,
        deeplink: str,
        data: dict[str, Any] | None = None,
        inbox_visible: bool = True,
        push_enabled: bool = True,
    ) -> Notification:
        notif = Notification.objects.create(
            user=user,
            title=title,
            body=body,
            type=event_type,
            category=category,
            data=data or {},
            deeplink=deeplink,
            inbox_visible=inbox_visible,
            push_enabled=push_enabled,
        )

        if push_enabled:
            def _enqueue() -> None:
                from .tasks import dispatch_notification_task
                try:
                    dispatch_notification_task.delay(str(notif.id))
                except Exception:
                    # Best-effort enqueue; inbox record is still valuable even if Celery is down.
                    pass

            transaction.on_commit(_enqueue)

        return notif

    @staticmethod
    def build_payload(notification: Notification) -> NotificationPayload:
        event_type = notification.type
        return NotificationPayload(
            title=notification.title,
            body=notification.body,
            type=_group_type(event_type),
            event=event_type,
            category=notification.category,
            deeplink=notification.deeplink,
            data=notification.data or {},
        )
