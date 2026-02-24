from decimal import Decimal, ROUND_HALF_UP

from .models import Coupon


def compute_coupon_discount(*, coupon: Coupon, order_items: list[dict]) -> dict:
    """
    order_items: list of dicts with keys:
      - product: Product instance
      - quantity: int
      - line_total: Decimal
    """
    eligible_subtotal = Decimal('0.00')
    subtotal = Decimal('0.00')

    has_product_filter = coupon.applicable_products.exists()
    has_category_filter = coupon.applicable_categories.exists()

    product_ids = set()
    category_ids = set()
    if has_product_filter:
        product_ids = set(coupon.applicable_products.values_list('id', flat=True))
    if has_category_filter:
        category_ids = set(coupon.applicable_categories.values_list('id', flat=True))

    for item in order_items:
        product = item['product']
        line_total = item['line_total']

        subtotal += line_total

        if coupon.scope == Coupon.Scope.VENDOR and product.vendor_id != coupon.vendor_id:
            continue

        if has_product_filter and product.id not in product_ids:
            continue

        if has_category_filter and (product.category_id not in category_ids):
            continue

        eligible_subtotal += line_total

    min_amount = coupon.min_order_amount
    if min_amount is not None and eligible_subtotal < min_amount:
        return {
            'ok': False,
            'error': f"Minimum eligible order amount is {min_amount}.",
        }

    discount = Decimal('0.00')
    if eligible_subtotal > 0:
        if coupon.discount_type == Coupon.DiscountType.PERCENT:
            discount = (eligible_subtotal * (coupon.discount_value / Decimal('100'))).quantize(
                Decimal('0.01'),
                rounding=ROUND_HALF_UP,
            )
        else:
            discount = min(coupon.discount_value, eligible_subtotal).quantize(
                Decimal('0.01'),
                rounding=ROUND_HALF_UP,
            )

    total_after_discount = (subtotal - discount).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    if total_after_discount < 0:
        total_after_discount = Decimal('0.00')

    return {
        'ok': True,
        'subtotal': subtotal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
        'eligible_subtotal': eligible_subtotal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
        'discount': discount,
        'total_after_discount': total_after_discount,
    }

