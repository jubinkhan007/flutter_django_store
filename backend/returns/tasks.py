from __future__ import annotations

from celery import shared_task
from django.db import transaction
from django.utils import timezone

from vendors.financial_service import FinancialService

from .models import Refund, ReturnRequest
from .sslcommerz_refund_client import SSLCommerzRefundClient


@shared_task
def poll_sslcommerz_refund_status(refund_id: int | None = None, batch_size: int = 50) -> int:
    """
    Polls SSLCommerz for ORIGINAL-method refunds that are still PROCESSING.

    - If `refund_id` is provided, only polls that refund.
    - Otherwise, polls up to `batch_size` refunds.
    """
    qs = Refund.objects.filter(
        provider='SSLCOMMERZ',
        status=Refund.Status.PROCESSING,
    ).exclude(provider_ref_id='')

    if refund_id is not None:
        qs = qs.filter(id=refund_id)
    else:
        qs = qs.order_by('created_at')[: max(1, int(batch_size))]

    refunds = list(qs.select_related('return_request'))
    if not refunds:
        return 0

    client = SSLCommerzRefundClient()
    completed = 0

    for refund in refunds:
        res = client.query_refund_status(refund_ref_id=refund.provider_ref_id)
        if res.api_connect != 'DONE':
            continue

        if res.status == 'processing':
            continue

        if res.status == 'refunded':
            with transaction.atomic():
                refund = Refund.objects.select_for_update().select_related('return_request').get(id=refund.id)
                if refund.status != Refund.Status.PROCESSING:
                    continue

                refund.status = Refund.Status.COMPLETED
                refund.processed_at = timezone.now()
                if not refund.reference:
                    refund.reference = refund.provider_ref_id
                refund.save(update_fields=['status', 'processed_at', 'reference', 'updated_at'])

                rr = ReturnRequest.objects.select_for_update().get(id=refund.return_request_id)
                if rr.status in (ReturnRequest.Status.RECEIVED, ReturnRequest.Status.REFUND_PENDING):
                    rr.status = ReturnRequest.Status.REFUNDED
                    rr.save(update_fields=['status', 'updated_at'])

                FinancialService.debit_for_refund(refund)

                # Customer notification on commit.
                def _notify() -> None:
                    try:
                        from notifications.models import Notification
                        from notifications.services import NotificationService

                        NotificationService.create(
                            user=rr.customer,
                            title='Refund processed',
                            body=f'Your refund for {rr.rma_number} has been processed.',
                            event_type=Notification.Type.REFUND_PROCESSED,
                            category=Notification.Category.TRANSACTIONAL,
                            deeplink=f'app://returns/{rr.id}',
                            data={'return_request_id': str(rr.id), 'refund_id': str(refund.id)},
                            inbox_visible=True,
                            push_enabled=True,
                        )
                    except Exception:
                        pass

                transaction.on_commit(_notify)

            completed += 1
            continue

        if res.status == 'cancelled':
            with transaction.atomic():
                refund = Refund.objects.select_for_update().get(id=refund.id)
                if refund.status != Refund.Status.PROCESSING:
                    continue

                refund.status = Refund.Status.FAILED
                refund.failure_reason = res.error_reason or 'Refund cancelled.'
                refund.save(update_fields=['status', 'failure_reason', 'updated_at'])

    return completed
