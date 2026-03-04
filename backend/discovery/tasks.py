from __future__ import annotations

from collections import Counter, defaultdict
from datetime import timedelta

from celery import shared_task
from django.db.models import Q
from django.utils import timezone

from orders.models import Order, OrderItem

from .models import ProductAffinity


@shared_task
def compute_product_affinities(*, window_days: int = 90, top_k: int = 50) -> dict:
    """
    Rebuilds ProductAffinity edges using co-occurrence in purchased orders.
    Keeps only the top_k outgoing edges per product.
    """
    cutoff = timezone.now() - timedelta(days=int(window_days))

    purchase_q = Q(payment_status=Order.PaymentStatus.PAID) | Q(
        payment_method=Order.PaymentMethod.COD,
        status=Order.Status.DELIVERED,
    )

    order_qs = (
        Order.objects.exclude(status=Order.Status.CANCELED)
        .filter(created_at__gte=cutoff)
        .filter(purchase_q)
    )

    # Load (order_id, product_id) pairs.
    rows = (
        OrderItem.objects.filter(
            sub_order__order__in=order_qs,
            product__isnull=False,
        )
        .values_list('sub_order__order_id', 'product_id')
        .iterator()
    )

    per_order: dict[int, set[int]] = defaultdict(set)
    for order_id, product_id in rows:
        if product_id:
            per_order[int(order_id)].add(int(product_id))

    outgoing: dict[int, Counter] = defaultdict(Counter)
    for product_ids in per_order.values():
        ids = list(product_ids)
        if len(ids) < 2:
            continue
        for i in range(len(ids)):
            for j in range(len(ids)):
                if i == j:
                    continue
                outgoing[ids[i]][ids[j]] += 1

    edges = []
    for from_id, counter in outgoing.items():
        for to_id, count in counter.most_common(int(top_k)):
            edges.append(
                ProductAffinity(
                    from_product_id=from_id,
                    to_product_id=to_id,
                    score=float(count),
                )
            )

    ProductAffinity.objects.all().delete()
    if edges:
        ProductAffinity.objects.bulk_create(edges, batch_size=2000)

    return {
        'window_days': int(window_days),
        'top_k': int(top_k),
        'orders_seen': len(per_order),
        'edges_written': len(edges),
        'cutoff': cutoff.isoformat(),
    }
