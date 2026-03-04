from __future__ import annotations

from datetime import timedelta

from django.db import models
from django.db.models import Count
from django.utils import timezone

from analytics.models import UserEvent
from orders.models import Order, OrderItem
from products.models import Product

from .models import Collection, ProductAffinity
from .ranking import DiscoveryRanker


class RecommendationService:
    def __init__(self, *, user=None, session_id=None):
        self.user = user if (user is not None and getattr(user, 'is_authenticated', False)) else None
        self.session_id = session_id
        self.ranker = DiscoveryRanker()

    def _event_qs(self):
        qs = UserEvent.objects.all()
        if self.user is not None:
            return qs.filter(user=self.user)
        if self.session_id:
            return qs.filter(session_id=self.session_id)
        return qs.none()

    def recently_viewed(self, *, limit: int = 12) -> list[Product]:
        events = (
            self._event_qs()
            .filter(event_type=UserEvent.EventType.VIEW, product__isnull=False)
            .order_by('-created_at')
            .values_list('product_id', flat=True)
        )
        seen = set()
        ids = []
        for pid in events[: limit * 5]:
            if pid in seen:
                continue
            seen.add(pid)
            ids.append(pid)
            if len(ids) >= limit:
                break
        if not ids:
            return []
        products = list(
            Product.objects.filter(id__in=ids, is_available=True).select_related('vendor', 'category')
        )
        by_id = {p.id: p for p in products}
        ordered = [by_id[pid] for pid in ids if pid in by_id]
        # Preserve recency ordering but enforce the availability gate within the section.
        in_stock = [p for p in ordered if p.is_available and (p.stock_quantity or 0) > 0]
        oos = [p for p in ordered if p not in in_stock]
        return (in_stock + oos)[:limit]

    def trending(self, *, limit: int = 12, days: int = 7) -> list[Product]:
        cutoff = timezone.now() - timedelta(days=days)
        purchase_q = (
            models.Q(
                orderitem__sub_order__order__payment_status=Order.PaymentStatus.PAID,
                orderitem__sub_order__order__status__in=[
                    Order.Status.PAID,
                    Order.Status.SHIPPED,
                    Order.Status.DELIVERED,
                ],
            )
            | models.Q(
                orderitem__sub_order__order__payment_method=Order.PaymentMethod.COD,
                orderitem__sub_order__order__status=Order.Status.DELIVERED,
            )
        )
        qs = (
            Product.objects.filter(is_available=True)
            .select_related('vendor', 'category')
            .annotate(
                order_count=Count(
                    'orderitem',
                    filter=models.Q(orderitem__sub_order__created_at__gte=cutoff) & purchase_q,
                )
            )
            .order_by('-order_count', '-created_at')
        )
        return self.ranker.rank(qs, limit=limit)

    def top_rated_in_category(self, category_id: int, *, limit: int = 12) -> list[Product]:
        qs = (
            Product.objects.filter(is_available=True, category_id=category_id)
            .select_related('vendor', 'category')
            .order_by('-avg_rating', '-review_count', '-created_at')
        )
        return self.ranker.rank(qs, limit=limit)

    def _top_browsed_category_id(self) -> int | None:
        rows = (
            self._event_qs()
            .filter(product__isnull=False, event_type__in=[UserEvent.EventType.VIEW, UserEvent.EventType.CLICK])
            .values('product__category_id')
            .annotate(c=Count('id'))
            .order_by('-c')
        )
        for row in rows[:1]:
            cid = row.get('product__category_id')
            if cid:
                return int(cid)
        return None

    def personalized_feed(self, *, limit: int = 12) -> list[Product]:
        category_id = self._top_browsed_category_id()
        if category_id:
            return self.top_rated_in_category(category_id, limit=limit)
        return []

    def fbt_from_last_purchase(self, *, limit: int = 12) -> list[Product]:
        if self.user is None:
            return []
        purchase_q = models.Q(payment_status=Order.PaymentStatus.PAID) | models.Q(
            payment_method=Order.PaymentMethod.COD,
            status=Order.Status.DELIVERED,
        )
        last_order = (
            Order.objects.filter(customer=self.user)
            .exclude(status=Order.Status.CANCELED)
            .filter(purchase_q)
            .order_by('-created_at')
            .first()
        )
        if not last_order:
            return []

        purchased_ids = list(
            OrderItem.objects.filter(sub_order__order=last_order, product__isnull=False)
            .values_list('product_id', flat=True)
            .distinct()
        )
        if not purchased_ids:
            return []

        # Take FBT from the most recent purchased product that has affinities.
        for pid in purchased_ids[:3]:
            edge_ids = list(
                ProductAffinity.objects.filter(from_product_id=pid)
                .order_by('-score')
                .values_list('to_product_id', flat=True)[: limit * 2]
            )
            if edge_ids:
                qs = Product.objects.filter(id__in=edge_ids, is_available=True).select_related('vendor', 'category')
                return self.ranker.rank(qs, limit=limit)

        return []

    def active_collections(self, *, limit: int = 6) -> list[Collection]:
        now = timezone.now()
        qs = Collection.objects.filter(is_active=True).order_by('-priority', 'starts_at')
        qs = qs.filter(models.Q(starts_at__isnull=True) | models.Q(starts_at__lte=now))
        qs = qs.filter(models.Q(ends_at__isnull=True) | models.Q(ends_at__gte=now))
        return list(qs[:limit])

    def home_payload(self) -> dict:
        """
        Returns a dict suitable for GET /api/discovery/home/
        """
        recently = self.recently_viewed(limit=12) if self.session_id else []

        if self.user is None:
            # Guest cold-start fallback chain.
            recommended = []
            if recently:
                category_id = recently[0].category_id
                if category_id:
                    recommended = self.top_rated_in_category(category_id, limit=12)
            if not recommended:
                recommended = self.trending(limit=12, days=7)
        else:
            recommended = self.personalized_feed(limit=12)
            if not recommended:
                recommended = self.fbt_from_last_purchase(limit=12)
            if not recommended:
                recommended = self.trending(limit=12, days=7)

        collections = self.active_collections(limit=6)
        return {
            'recently_viewed': recently,
            'recommended': recommended,
            'trending': self.trending(limit=12, days=7),
            'collections': collections,
        }

    def recommendations_for_product(self, product_id: int, *, limit: int = 12) -> dict:
        edge_ids = list(
            ProductAffinity.objects.filter(from_product_id=product_id)
            .order_by('-score')
            .values_list('to_product_id', flat=True)[: limit * 3]
        )

        if edge_ids:
            fbt_qs = Product.objects.filter(id__in=edge_ids, is_available=True).select_related(
                'vendor', 'category'
            )
            frequently_bought_together = self.ranker.rank(fbt_qs, limit=min(limit, 8))
        else:
            # Cold-start fallback: never return empty bundles when we can avoid it.
            try:
                base = Product.objects.get(id=product_id)
                fallback_qs = (
                    Product.objects.filter(is_available=True, category_id=base.category_id)
                    .exclude(id=product_id)
                    .select_related('vendor', 'category')
                    .order_by('-avg_rating', '-review_count', '-created_at')
                )
            except Product.DoesNotExist:
                fallback_qs = Product.objects.none()
            frequently_bought_together = self.ranker.rank(fallback_qs, limit=min(limit, 8))
            if not frequently_bought_together:
                frequently_bought_together = self.trending(limit=min(limit, 8), days=7)

        # Similar items: affinity first, then category fallback.
        if edge_ids:
            similar_qs = Product.objects.filter(id__in=edge_ids, is_available=True).select_related('vendor', 'category')
        else:
            try:
                base = Product.objects.get(id=product_id)
                similar_qs = Product.objects.filter(
                    is_available=True,
                    category_id=base.category_id,
                ).exclude(id=product_id)
            except Product.DoesNotExist:
                similar_qs = Product.objects.none()

        similar_items = self.ranker.rank(similar_qs.exclude(id=product_id), limit=min(limit, 12))

        return {
            'similar_items': similar_items,
            'frequently_bought_together': frequently_bought_together,
        }
