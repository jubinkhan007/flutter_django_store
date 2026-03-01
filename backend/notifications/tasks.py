from __future__ import annotations

import json

import requests
from celery import shared_task
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import DeviceToken, Notification, NotificationPreference
from .services import NotificationService


def _should_push(notification: Notification) -> bool:
    if not notification.push_enabled:
        return False

    pref, _ = NotificationPreference.objects.get_or_create(user=notification.user)

    if notification.category == Notification.Category.PROMOTION:
        return pref.promotions

    if notification.type in (
        Notification.Type.PAYOUT_APPROVED,
        Notification.Type.PAYOUT_REQUESTED,
    ):
        return pref.payout_updates

    # Orders + refunds fall under order_updates
    return pref.order_updates


def _send_fcm(*, tokens: list[str], payload: dict) -> tuple[bool, dict]:
    mode = (getattr(settings, 'FCM_MODE', 'v1') or 'v1').lower()

    if mode == 'legacy':
        server_key = getattr(settings, 'FCM_SERVER_KEY', '') or ''
        if not server_key.strip():
            return False, {'skip': True, 'error': 'FCM_SERVER_KEY not configured.'}

        url = 'https://fcm.googleapis.com/fcm/send'
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'key={server_key}',
        }

        body = {
            'registration_ids': tokens,
            'priority': 'high'
            if payload.get('category') == Notification.Category.TRANSACTIONAL
            else 'normal',
            'notification': {
                'title': payload.get('title', ''),
                'body': payload.get('body', ''),
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'android_channel_id': 'shopease_default',
            },
            'data': payload,
        }

        resp = requests.post(url, headers=headers, data=json.dumps(body), timeout=20)
        try:
            data = resp.json()
        except Exception:
            data = {'raw': resp.text[:1000], 'status_code': resp.status_code}

        ok = resp.status_code == 200
        return ok, data

    # HTTP v1 (default)
    try:
        from .fcm_v1_client import FCMV1Client

        client = FCMV1Client()
    except Exception as e:
        return False, {'skip': True, 'error': str(e)}

    any_ok = False
    results: list[dict] = []
    for t in tokens:
        ok, res = client.send_to_token(token=t, payload=payload)
        any_ok = any_ok or ok
        results.append({'token': t, 'ok': ok, 'response': res})

        # Token pruning hint: mark inactive if UNREGISTERED.
        if not ok and isinstance(res, dict):
            err = res.get('error') if isinstance(res.get('error'), dict) else {}
            status = err.get('status')
            details = err.get('details') if isinstance(err.get('details'), list) else []
            error_codes = [d.get('errorCode') for d in details if isinstance(d, dict)]
            if status in ('NOT_FOUND',) or 'UNREGISTERED' in error_codes:
                DeviceToken.objects.filter(token=t).update(is_active=False)

    return any_ok, {'results': results}


@shared_task(bind=True, autoretry_for=(requests.RequestException,), retry_backoff=True, retry_kwargs={'max_retries': 5})
def dispatch_notification_task(self, notification_id: str) -> None:
    try:
        notification = Notification.objects.select_related('user').get(id=notification_id)
    except Notification.DoesNotExist:
        return

    if notification.delivery_status in (
        Notification.DeliveryStatus.SENT,
        Notification.DeliveryStatus.SKIPPED,
    ):
        return

    if not _should_push(notification):
        notification.delivery_status = Notification.DeliveryStatus.SKIPPED
        notification.delivery_error = 'Push disabled by preference.'
        notification.save(update_fields=['delivery_status', 'delivery_error', 'updated_at'])
        return

    tokens_qs = DeviceToken.objects.filter(user=notification.user, is_active=True)
    tokens = list(tokens_qs.values_list('token', flat=True))
    if not tokens:
        notification.delivery_status = Notification.DeliveryStatus.SKIPPED
        notification.delivery_error = 'No active device tokens.'
        notification.save(update_fields=['delivery_status', 'delivery_error', 'updated_at'])
        return

    payload = NotificationService.build_payload(notification)
    ok, res = _send_fcm(tokens=tokens, payload={
        'title': payload.title,
        'body': payload.body,
        'type': payload.type,
        'event': payload.event,
        'category': payload.category,
        'deeplink': payload.deeplink,
        'data': payload.data,
    })

    # Token pruning: mark inactive when FCM returns NotRegistered / InvalidRegistration.
    results = res.get('results') if isinstance(res, dict) else None
    if isinstance(results, list) and len(results) == len(tokens):
        bad_tokens: list[str] = []
        for token, item in zip(tokens, results):
            if not isinstance(item, dict):
                continue
            err = item.get('error')
            if err in ('NotRegistered', 'InvalidRegistration'):
                bad_tokens.append(token)
        if bad_tokens:
            DeviceToken.objects.filter(token__in=bad_tokens).update(is_active=False)

    with transaction.atomic():
        notification = Notification.objects.select_for_update().get(id=notification_id)
        if ok:
            notification.delivery_status = Notification.DeliveryStatus.SENT
            notification.delivered_at = timezone.now()
            notification.delivery_error = ''
        else:
            should_skip = isinstance(res, dict) and res.get('skip') is True
            notification.delivery_status = (
                Notification.DeliveryStatus.SKIPPED if should_skip else Notification.DeliveryStatus.FAILED
            )
            notification.delivery_error = (res.get('error') if isinstance(res, dict) else '') or (
                'FCM send failed.' if not should_skip else 'Push disabled.'
            )
        notification.save(update_fields=['delivery_status', 'delivered_at', 'delivery_error', 'updated_at'])
