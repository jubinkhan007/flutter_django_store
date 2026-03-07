"""
Cross-border sourcing services: quote generation and checkout.
"""
from __future__ import annotations

from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils import timezone

from orders.models import SubOrder
from vendors.models import Vendor

from .models import CrossBorderCostConfig, CrossBorderOrderRequest


def _d(value) -> Decimal:
    return Decimal(str(value)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


class CrossBorderQuoteService:
    """
    Generates a cost breakdown for a CB purchase.
    Policy A: platform collects item_price + intl_shipping + service_fee.
    Customs is an informational estimate only (paid by customer to courier on delivery).
    """

    QUOTE_TTL_MINUTES = 30

    @classmethod
    def get_config(cls, shipping_method: str) -> CrossBorderCostConfig:
        config = CrossBorderCostConfig.objects.filter(
            shipping_method=shipping_method, is_active=True
        ).first()
        if not config:
            # Sensible defaults
            config = CrossBorderCostConfig(
                shipping_method=shipping_method,
                rate_per_kg=_d(500 if shipping_method == 'AIR' else 150),
                service_fee_type='PERCENTAGE',
                service_fee_value=_d(10),
                customs_rate_percentage=_d(25),
                fx_rate_bdt=_d(110),
            )
        return config

    @classmethod
    def generate_quote(
        cls,
        *,
        item_price_foreign: Decimal,
        currency: str = 'USD',
        weight_kg: Decimal,
        shipping_method: str = 'AIR',
        quantity: int = 1,
    ) -> dict:
        """Returns a breakdown dict in BDT."""
        config = cls.get_config(shipping_method)
        fx = config.fx_rate_bdt

        item_price_bdt = _d(item_price_foreign * fx * quantity)
        intl_shipping_bdt = _d(weight_kg * quantity * config.rate_per_kg)

        if config.service_fee_type == 'FIXED':
            service_fee_bdt = _d(config.service_fee_value)
        else:
            service_fee_bdt = _d(item_price_bdt * config.service_fee_value / 100)

        customs_est_bdt = _d(item_price_bdt * config.customs_rate_percentage / 100)
        total_bdt = _d(item_price_bdt + intl_shipping_bdt + service_fee_bdt)

        return {
            'item_price_bdt': float(item_price_bdt),
            'intl_shipping_bdt': float(intl_shipping_bdt),
            'service_fee_bdt': float(service_fee_bdt),
            'customs_est_bdt': float(customs_est_bdt),
            'total_bdt': float(total_bdt),
            'currency': currency,
            'item_price_foreign': float(item_price_foreign),
            'fx_rate_bdt': float(fx),
        }

    @classmethod
    def apply_quote_to_request(
        cls,
        request: CrossBorderOrderRequest,
        shipping_method: str = 'AIR',
    ) -> CrossBorderOrderRequest:
        """Compute and stamp a quote onto an existing CB request."""
        cb_product = request.crossborder_product

        if cb_product:
            item_price = cb_product.base_price_foreign
            currency = cb_product.currency
            weight_kg = cb_product.estimated_weight_kg
        else:
            # For LINK_PURCHASE we use a placeholder; ops will finalize cost later
            item_price = _d(0)
            currency = 'USD'
            weight_kg = _d(0.5)

        breakdown = cls.generate_quote(
            item_price_foreign=item_price,
            currency=currency,
            weight_kg=weight_kg,
            shipping_method=shipping_method,
            quantity=request.quantity,
        )
        config = cls.get_config(shipping_method)

        request.estimated_cost_breakdown = breakdown
        request.shipping_method = shipping_method
        request.quote_expires_at = timezone.now() + timedelta(minutes=cls.QUOTE_TTL_MINUTES)
        request.quoted_at = timezone.now()
        request.status = CrossBorderOrderRequest.Status.QUOTED
        request.expected_delivery_days_min = (
            cb_product.lead_time_days_min if cb_product else 7
        )
        request.expected_delivery_days_max = (
            cb_product.lead_time_days_max if cb_product else 21
        )
        return request


class CrossBorderCheckoutService:
    """Validates disclosure acceptance and finalizes payment, creating a SubOrder."""

    @classmethod
    def checkout(
        cls,
        *,
        cb_request: CrossBorderOrderRequest,
        customs_policy_acknowledged: bool,
    ) -> CrossBorderOrderRequest:
        if not customs_policy_acknowledged:
            raise ValueError('Customer must acknowledge the customs policy to proceed.')

        if not cb_request.is_quote_valid:
            raise ValueError('Quote has expired. Please request a new quote.')

        if cb_request.status != CrossBorderOrderRequest.Status.QUOTED:
            raise ValueError(f'Request is not in QUOTED state (current: {cb_request.status}).')

        # Ensure the customer has a valid address snapshot
        if not cb_request.customer_address_snapshot:
            raise ValueError('Delivery address is required.')

        with transaction.atomic():
            # Create a stub SubOrder (no vendor; CB requests are platform-managed)
            # We use a platform "ops" vendor; fall back to any vendor if none configured
            platform_vendor = _get_platform_vendor()

            from orders.models import Order
            order = Order.objects.create(
                customer=cb_request.customer,
                total_amount=_d(cb_request.estimated_cost_breakdown.get('total_bdt', 0)),
                subtotal_amount=_d(cb_request.estimated_cost_breakdown.get('item_price_bdt', 0)),
                status=Order.Status.PENDING,
                payment_method=Order.PaymentMethod.ONLINE,
                payment_status=Order.PaymentStatus.UNPAID,
            )

            sub_order = SubOrder.objects.create(
                order=order,
                vendor=platform_vendor,
                status=Order.Status.PENDING,
                fulfillment_type=SubOrder.FulfillmentType.CROSS_BORDER_DIRECT,
            )

            cb_request.sub_order = sub_order
            cb_request.customs_policy_acknowledged = True
            cb_request.status = CrossBorderOrderRequest.Status.PAYMENT_RECEIVED
            cb_request.save()

        return cb_request


def _get_platform_vendor() -> Vendor:
    """
    Returns the platform operator vendor used for CB orders.
    Looks for a vendor with store_name='PLATFORM_OPS', creating a stub if missing.
    """
    vendor = Vendor.objects.filter(store_name='PLATFORM_OPS').first()
    if vendor:
        return vendor
    from django.contrib.auth import get_user_model
    User = get_user_model()
    ops_user, _ = User.objects.get_or_create(
        username='platform_ops',
        defaults={
            'email': 'ops@platform.internal',
            'is_active': False,
        },
    )
    vendor, _ = Vendor.objects.get_or_create(
        store_name='PLATFORM_OPS',
        defaults={'user': ops_user, 'is_approved': True},
    )
    return vendor
