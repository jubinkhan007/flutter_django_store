from __future__ import annotations

from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.utils import timezone

from .models import UserEvent


@shared_task
def purge_old_user_events() -> dict:
    """
    Deletes raw UserEvent rows older than the retention window.
    Intended to run on a schedule (Celery Beat).
    """
    retention_days = int(getattr(settings, 'ANALYTICS_RETENTION_DAYS', 90))
    cutoff = timezone.now() - timedelta(days=retention_days)
    deleted, _ = UserEvent.objects.filter(created_at__lt=cutoff).delete()
    return {'deleted': deleted, 'cutoff': cutoff.isoformat(), 'retention_days': retention_days}

