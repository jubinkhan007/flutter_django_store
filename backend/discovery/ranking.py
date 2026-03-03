from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta

from django.db.models import Count
from django.utils import timezone

from orders.models import OrderItem
from orders.models import Order
from products.models import Product


@dataclass(frozen=True)
class RankedProduct:
    product: Product
    score: float
    in_stock: bool


class DiscoveryRanker:
    """
    Enforces an Availability Gate:
      - In-stock products always rank above out-of-stock products.
    """

    def __init__(self, *, velocity_days: int = 7):
        self.velocity_days = velocity_days

    def rank(self, qs, *, limit: int = 24) -> list[Product]:
        products = list(qs[: max(limit * 5, limit)])
        if not products:
            return []

        now = timezone.now()
        cutoff = now - timedelta(days=self.velocity_days)

        ids = [p.id for p in products]
        velocity_rows = (
            OrderItem.objects.filter(
                product_id__in=ids,
                sub_order__created_at__gte=cutoff,
                sub_order__order__payment_status=Order.PaymentStatus.PAID,
            )
            .exclude(sub_order__order__status=Order.Status.CANCELED)
            .values('product_id')
            .annotate(c=Count('id'))
        )
        velocity = {row['product_id']: int(row['c']) for row in velocity_rows}
        max_velocity = max(velocity.values(), default=0)

        ranked: list[RankedProduct] = []
        for p in products:
            in_stock = bool(p.is_available and (p.stock_quantity or 0) > 0)

            rating_score = min(max(float(getattr(p, 'avg_rating', 0.0)) / 5.0, 0.0), 1.0)

            age_days = (now - p.created_at).days if getattr(p, 'created_at', None) else 365
            newness_score = 1.0 - min(max(age_days / 30.0, 0.0), 1.0)

            v = velocity.get(p.id, 0)
            velocity_score = (v / max_velocity) if max_velocity > 0 else 0.0

            score = (0.45 * velocity_score) + (0.35 * rating_score) + (0.20 * newness_score)
            ranked.append(RankedProduct(product=p, score=score, in_stock=in_stock))

        ranked.sort(
            key=lambda rp: (
                1 if rp.in_stock else 0,
                rp.score,
                rp.product.created_at,
            ),
            reverse=True,
        )
        return [rp.product for rp in ranked[:limit]]
