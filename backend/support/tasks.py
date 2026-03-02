from __future__ import annotations

from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from .models import Ticket


@shared_task
def flag_overdue_tickets() -> int:
    """
    Daily SLA monitoring:
      - 24h first response
      - 72h resolution
    """
    now = timezone.now()
    first_due = now - timedelta(hours=24)
    resolve_due = now - timedelta(hours=72)

    qs = Ticket.objects.exclude(status__in=[Ticket.Status.RESOLVED, Ticket.Status.CLOSED])

    updated = 0
    for t in qs:
        dirty = False
        if t.first_response_at is None and t.created_at and t.created_at <= first_due:
            if not t.is_overdue_first_response:
                t.is_overdue_first_response = True
                dirty = True
        if t.resolved_at is None and t.created_at and t.created_at <= resolve_due:
            if not t.is_overdue_resolution:
                t.is_overdue_resolution = True
                dirty = True
        if dirty:
            t.save(update_fields=['is_overdue_first_response', 'is_overdue_resolution', 'updated_at'])
            updated += 1
    return updated

