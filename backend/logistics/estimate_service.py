from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import timedelta
from decimal import Decimal
from typing import Any

from django.db.models import Q
from django.utils import timezone

from products.models import Product, ProductVariant
from returns.models import ReturnPolicy


def _normalize_city_name(city: str) -> str:
    c = (city or '').strip().lower()
    if 'dhaka' in c:
        return 'dhaka'
    if 'chittagong' in c or 'chattogram' in c:
        return 'chittagong'
    if 'sylhet' in c:
        return 'sylhet'
    if 'rajshahi' in c:
        return 'rajshahi'
    if 'khulna' in c:
        return 'khulna'
    if 'barisal' in c or 'barishal' in c:
        return 'barisal'
    if 'rangpur' in c:
        return 'rangpur'
    if 'mymensingh' in c:
        return 'mymensingh'
    if 'comilla' in c or 'cumilla' in c:
        return 'comilla'
    if 'gazipur' in c:
        return 'gazipur'
    if 'narayanganj' in c:
        return 'narayanganj'
    return c


@dataclass(frozen=True)
class DeliveryOption:
    code: str
    title: str
    courier_partner: str
    fee: float
    fee_display: str
    is_free: bool
    min_days: int
    max_days: int
    estimated_delivery_start: str
    estimated_delivery_end: str
    estimated_delivery_display: str
    badge: str


class DeliveryEstimateService:
    FREE_SHIPPING_THRESHOLD = Decimal('2000.00')

    @classmethod
    def calculate_estimate(
        cls,
        product: Product,
        destination_city: str | None = None,
        destination_area: str | None = None,
        quantity: int = 1,
        variant: ProductVariant | None = None,
    ) -> dict[str, Any]:
        dest_city_clean = (destination_city or 'Dhaka').strip()
        dest_area_clean = (destination_area or '').strip()

        # Determine vendor origin city
        vendor = product.vendor
        origin_city = 'Dhaka'
        if vendor:
            from logistics.models import LogisticsStore
            st = (
                LogisticsStore.objects.filter(is_active=True)
                .filter(Q(owner_vendor=vendor) | Q(assigned_vendors=vendor))
                .first()
            )
            if st and st.city:
                origin_city = st.city.strip()
            elif getattr(vendor, 'location', None) and vendor.location.strip():
                origin_city = vendor.location.strip()

        norm_origin = _normalize_city_name(origin_city)
        norm_dest = _normalize_city_name(dest_city_clean)
        is_inside_city = bool(norm_origin and norm_dest and (norm_origin == norm_dest))

        # Check pricing and free shipping qualification
        unit_price = variant.effective_price if variant else product.price
        total_price = (unit_price or Decimal('0.00')) * max(1, quantity)
        qualifies_for_free_shipping = total_price >= cls.FREE_SHIPPING_THRESHOLD

        today = timezone.now().date()

        # Standard Delivery Option
        std_min_days = 2 if is_inside_city else 3
        std_max_days = 3 if is_inside_city else 5
        std_fee = Decimal('0.00') if qualifies_for_free_shipping else (Decimal('60.00') if is_inside_city else Decimal('120.00'))
        std_fee_float = float(std_fee)

        std_start_date = today + timedelta(days=std_min_days)
        std_end_date = today + timedelta(days=std_max_days)

        std_start_str = std_start_date.strftime('%Y-%m-%d')
        std_end_str = std_end_date.strftime('%Y-%m-%d')
        std_display = f"{std_start_date.strftime('%d %b')} - {std_end_date.strftime('%d %b')}"

        std_option = DeliveryOption(
            code="STANDARD",
            title="Free Standard Delivery" if qualifies_for_free_shipping else "Standard Delivery",
            courier_partner="Steadfast / RedX",
            fee=std_fee_float,
            fee_display="FREE" if qualifies_for_free_shipping else f"৳{std_fee:,.0f}",
            is_free=qualifies_for_free_shipping,
            min_days=std_min_days,
            max_days=std_max_days,
            estimated_delivery_start=std_start_str,
            estimated_delivery_end=std_end_str,
            estimated_delivery_display=std_display,
            badge="Popular",
        )

        # Express Delivery Option
        exp_min_days = 1 if is_inside_city else 2
        exp_max_days = 2 if is_inside_city else 3
        exp_fee = Decimal('120.00') if is_inside_city else Decimal('180.00')
        exp_fee_float = float(exp_fee)

        exp_start_date = today + timedelta(days=exp_min_days)
        exp_end_date = today + timedelta(days=exp_max_days)

        exp_start_str = exp_start_date.strftime('%Y-%m-%d')
        exp_end_str = exp_end_date.strftime('%Y-%m-%d')
        exp_display = f"{exp_start_date.strftime('%d %b')} - {exp_end_date.strftime('%d %b')}"

        exp_option = DeliveryOption(
            code="EXPRESS",
            title="Express Next-Day" if is_inside_city else "Express Courier",
            courier_partner="Pathao Express",
            fee=exp_fee_float,
            fee_display=f"৳{exp_fee:,.0f}",
            is_free=False,
            min_days=exp_min_days,
            max_days=exp_max_days,
            estimated_delivery_start=exp_start_str,
            estimated_delivery_end=exp_end_str,
            estimated_delivery_display=exp_display,
            badge="Fastest",
        )

        # Return Policy Resolution
        return_policy = (
            ReturnPolicy.objects.filter(is_active=True)
            .filter(
                Q(product=product)
                | Q(vendor=product.vendor)
                | Q(category=product.category)
            )
            .first()
        )
        return_days = return_policy.return_window_days if return_policy else 7
        allow_return = return_policy.allow_return if return_policy else True

        return {
            'destination': {
                'city': dest_city_clean,
                'area': dest_area_clean,
                'is_inside_city': is_inside_city,
            },
            'origin': {
                'vendor_name': vendor.store_name if vendor else 'Store',
                'vendor_city': origin_city,
            },
            'options': [asdict(std_option), asdict(exp_option)],
            'cash_on_delivery': {
                'is_available': True,
                'fee': 0.00,
                'fee_display': 'Free',
            },
            'return_policy': {
                'return_window_days': return_days,
                'allow_return': allow_return,
                'policy_note': f"{return_days} Days Easy Return" if allow_return else "Non-Returnable Item",
            },
            'free_shipping_threshold': float(cls.FREE_SHIPPING_THRESHOLD),
            'qualifies_for_free_shipping': qualifies_for_free_shipping,
        }
