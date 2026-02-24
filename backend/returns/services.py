from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db.models import Q
from django.utils import timezone

from orders.models import Order, OrderItem
from products.models import Category, Product
from vendors.models import Vendor

from .models import Refund, ReturnItem, ReturnPolicy, ReturnRequest


@dataclass(frozen=True)
class EligibilityResult:
    ok: bool
    error: str | None = None


def resolve_return_policy(*, vendor: Vendor, product: Product) -> ReturnPolicy | None:
    qs = ReturnPolicy.objects.filter(is_active=True)

    # Priority: product > (vendor+category) > vendor > category > global
    product_policy = qs.filter(product=product).order_by('-updated_at').first()
    if product_policy:
        return product_policy

    vendor_category_policy = qs.filter(vendor=vendor, category=product.category).order_by('-updated_at').first()
    if vendor_category_policy:
        return vendor_category_policy

    vendor_policy = qs.filter(vendor=vendor, category__isnull=True, product__isnull=True).order_by('-updated_at').first()
    if vendor_policy:
        return vendor_policy

    category_policy = qs.filter(category=product.category, vendor__isnull=True, product__isnull=True).order_by('-updated_at').first()
    if category_policy:
        return category_policy

    global_policy = qs.filter(vendor__isnull=True, category__isnull=True, product__isnull=True).order_by('-updated_at').first()
    return global_policy


def check_return_eligibility(
    *,
    order: Order,
    vendor: Vendor,
    items: list[dict],
    request_type: str,
) -> EligibilityResult:
    """
    items: list of dicts with keys:
      - order_item: OrderItem
      - quantity: int
      - condition: ReturnRequest.ItemCondition
    """
    if order.customer_id is None:
        return EligibilityResult(False, 'Invalid order.')

    if order.status != Order.Status.DELIVERED:
        return EligibilityResult(False, 'Only DELIVERED orders are eligible for return/replace.')

    delivered_at = getattr(order, 'delivered_at', None) or order.updated_at
    if delivered_at is None:
        delivered_at = timezone.now()

    for it in items:
        order_item: OrderItem = it['order_item']
        product = order_item.product
        if product is None:
            return EligibilityResult(False, 'One of the products in your order is no longer available for return.')
        if product.vendor_id != vendor.id:
            return EligibilityResult(False, 'All return items must belong to the same vendor.')

        policy = resolve_return_policy(vendor=vendor, product=product)
        window_days = policy.return_window_days if policy else getattr(settings, 'RMA_DEFAULT_RETURN_WINDOW_DAYS', 7)

        if product.category and getattr(product.category, 'is_sealed', False):
            if policy and policy.sealed_return_window_days is not None:
                window_days = policy.sealed_return_window_days
            if policy and policy.sealed_requires_unopened:
                if it.get('condition') != ReturnRequest.ItemCondition.UNOPENED:
                    return EligibilityResult(False, 'Sealed items must be unopened to be eligible.')

        if policy:
            if request_type == ReturnRequest.RequestType.RETURN and not policy.allow_return:
                return EligibilityResult(False, 'Returns are not allowed for this item.')
            if request_type == ReturnRequest.RequestType.REPLACE and not policy.allow_replace:
                return EligibilityResult(False, 'Replacements are not allowed for this item.')

        if timezone.now() > delivered_at + timedelta(days=window_days):
            return EligibilityResult(False, f'Return window expired ({window_days} days).')

    return EligibilityResult(True, None)


def compute_refund_amount(*, return_request: ReturnRequest) -> Decimal:
    total = Decimal('0.00')
    for item in return_request.items.select_related('order_item').all():
        oi = item.order_item
        total += (oi.price * item.quantity)
    return total.quantize(Decimal('0.01'))


def create_refund(
    *,
    return_request: ReturnRequest,
    amount: Decimal | None = None,
    method: str,
) -> Refund:
    if amount is None:
        amount = compute_refund_amount(return_request=return_request)

    refundable = compute_refund_amount(return_request=return_request)
    if amount <= 0:
        raise ValueError('Refund amount must be > 0.')
    if amount > refundable:
        raise ValueError('Refund amount exceeds refundable total.')

    refund = Refund.objects.create(
        return_request=return_request,
        order=return_request.order,
        amount=amount,
        method=method,
        status=Refund.Status.PENDING,
    )
    return refund


def process_wallet_refund(*, refund: Refund) -> Refund:
    user = refund.return_request.customer
    # User model is in users app and may include wallet_balance.
    if not hasattr(user, 'wallet_balance'):
        refund.status = Refund.Status.FAILED
        refund.failure_reason = 'Wallet refunds are not supported.'
        refund.processed_at = timezone.now()
        refund.save()
        return refund

    user.wallet_balance = (user.wallet_balance or Decimal('0.00')) + refund.amount
    user.save(update_fields=['wallet_balance'])

    # Optional transaction log (if model exists)
    try:
        from users.models import CustomerWalletTransaction  # type: ignore

        CustomerWalletTransaction.objects.create(
            user=user,
            amount=refund.amount,
            transaction_type=CustomerWalletTransaction.TransactionType.CREDIT,
            description=f"Refund for {refund.return_request.rma_number}",
        )
    except Exception:
        pass

    refund.status = Refund.Status.COMPLETED
    refund.processed_at = timezone.now()
    refund.save()
    return refund


def escalate_overdue_returns() -> int:
    """
    Escalate SUBMITTED return requests that passed their vendor_response_due_at.
    """
    now = timezone.now()
    qs = ReturnRequest.objects.filter(
        status=ReturnRequest.Status.SUBMITTED,
        vendor_response_due_at__isnull=False,
        vendor_response_due_at__lt=now,
    )
    updated = 0
    for rr in qs:
        rr.status = ReturnRequest.Status.ESCALATED
        rr.escalated_at = now
        rr.save(update_fields=['status', 'escalated_at', 'updated_at'])
        updated += 1
    return updated

