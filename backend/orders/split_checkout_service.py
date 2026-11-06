from __future__ import annotations

import uuid
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Dict, List, Optional

from django.db import transaction
from django.utils import timezone
from django.conf import settings

from products.models import Product, ProductVariant
from coupons.models import Coupon
from coupons.services import compute_coupon_discount
from loyalty.models import LoyaltyAccount
from users.models import Address, CustomerWalletTransaction


class MultiVendorSplitCheckoutService:
    """
    Handles multi-vendor cart validation, partial coupon & loyalty allocations,
    sub-order generation, and combined single-transaction payments (bKash, Nagad, SSLCommerz).
    """

    DEFAULT_VENDOR_SHIPPING_FEE = Decimal('0.00')

    @classmethod
    def compute_multi_vendor_quote(
        cls,
        items_data: List[Dict[str, Any]],
        coupon_code: Optional[str] = None,
        redeem_points: int = 0,
        user=None,
        use_wallet: bool = False,
        requested_wallet_amount: Optional[Decimal] = None,
    ) -> Dict[str, Any]:
        """
        Calculates pricing breakdown split across each vendor with exact
        partial coupon discount and loyalty discount allocations.
        """
        # 1. Group items by vendor
        vendor_groups: Dict[int, Dict[str, Any]] = {}
        stock_warnings: List[Dict[str, Any]] = []
        overall_subtotal = Decimal('0.00')

        for item in items_data:
            product_id = item.get('product')
            quantity = int(item.get('quantity') or 1)
            variant_id = item.get('variant')

            try:
                product = Product.objects.select_related('vendor', 'category').get(
                    id=product_id, is_available=True
                )
            except Product.DoesNotExist:
                raise ValueError(f"Product #{product_id} is unavailable or not found.")

            variant = None
            available_stock = product.stock_quantity
            unit_price = product.price
            sku = ''
            variant_name = ''

            if variant_id:
                try:
                    variant = ProductVariant.objects.get(id=variant_id, product=product)
                    available_stock = variant.available_stock
                    unit_price = variant.effective_price
                    sku = variant.sku
                    variant_name = ", ".join([v.value for v in variant.option_values.all()])
                except ProductVariant.DoesNotExist:
                    raise ValueError(f"Variant #{variant_id} not found for '{product.name}'.")

            if available_stock < quantity:
                stock_warnings.append({
                    'product_id': product.id,
                    'product_name': product.name,
                    'variant_id': variant.id if variant else None,
                    'requested': quantity,
                    'available': available_stock,
                })

            line_total = (unit_price * quantity).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            overall_subtotal += line_total

            vendor = product.vendor
            if vendor.id not in vendor_groups:
                vendor_groups[vendor.id] = {
                    'vendor': vendor,
                    'vendor_id': vendor.id,
                    'store_name': vendor.store_name,
                    'subtotal': Decimal('0.00'),
                    'shipping_fee': cls.DEFAULT_VENDOR_SHIPPING_FEE,
                    'items': [],
                    'eligible_for_coupon_subtotal': Decimal('0.00'),
                }

            vendor_groups[vendor.id]['subtotal'] += line_total
            vendor_groups[vendor.id]['items'].append({
                'product': product,
                'product_id': product.id,
                'product_name': product.name,
                'variant': variant,
                'variant_id': variant.id if variant else None,
                'variant_name': variant_name,
                'sku': sku,
                'unit_price': unit_price,
                'quantity': quantity,
                'line_total': line_total,
                'image_url': product.image.url if product.image else '',
            })

        # 2. Coupon Validation & Partial Proportional Allocation
        coupon = None
        coupon_label = None
        total_coupon_discount = Decimal('0.00')

        if coupon_code and coupon_code.strip():
            code = coupon_code.strip().upper()
            try:
                coupon = Coupon.objects.get(code=code, is_active=True)
                order_items_compat = []
                for v_info in vendor_groups.values():
                    for itm in v_info['items']:
                        order_items_compat.append({
                            'product': itm['product'],
                            'vendor': v_info['vendor'],
                            'price': itm['unit_price'],
                            'quantity': itm['quantity'],
                            'line_total': itm['line_total'],
                        })

                coupon_result = compute_coupon_discount(coupon=coupon, order_items=order_items_compat)
                if coupon_result['ok']:
                    total_coupon_discount = coupon_result['discount']
                    coupon_label = coupon.code

                    # Calculate each vendor's eligible subtotal
                    has_prod_filter = coupon.applicable_products.exists()
                    has_cat_filter = coupon.applicable_categories.exists()
                    prod_ids = set(coupon.applicable_products.values_list('id', flat=True)) if has_prod_filter else set()
                    cat_ids = set(coupon.applicable_categories.values_list('id', flat=True)) if has_cat_filter else set()

                    for v_id, v_data in vendor_groups.items():
                        v_eligible = Decimal('0.00')
                        if coupon.scope == Coupon.Scope.VENDOR and v_id != coupon.vendor_id:
                            v_eligible = Decimal('0.00')
                        else:
                            for itm in v_data['items']:
                                prod = itm['product']
                                if has_prod_filter and prod.id not in prod_ids:
                                    continue
                                if has_cat_filter and prod.category_id not in cat_ids:
                                    continue
                                v_eligible += itm['line_total']
                        v_data['eligible_for_coupon_subtotal'] = v_eligible
            except Coupon.DoesNotExist:
                pass

        # Distribute coupon discount proportionally across eligible vendors
        total_eligible = sum(v['eligible_for_coupon_subtotal'] for v in vendor_groups.values())
        allocated_coupon_sum = Decimal('0.00')
        highest_eligible_vid = None
        max_eligible = Decimal('-1.00')

        for v_id, v_data in vendor_groups.items():
            v_eligible = v_data['eligible_for_coupon_subtotal']
            if v_eligible > max_eligible:
                max_eligible = v_eligible
                highest_eligible_vid = v_id

            if total_eligible > Decimal('0.00') and total_coupon_discount > Decimal('0.00'):
                share = (v_eligible / total_eligible) * total_coupon_discount
                v_disc = share.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            else:
                v_disc = Decimal('0.00')

            v_data['coupon_discount'] = v_disc
            allocated_coupon_sum += v_disc

        # Reconcile rounding discrepancy to the largest vendor
        if highest_eligible_vid is not None and allocated_coupon_sum != total_coupon_discount:
            diff = total_coupon_discount - allocated_coupon_sum
            vendor_groups[highest_eligible_vid]['coupon_discount'] += diff

        # 3. Loyalty Points Redemption & Partial Allocation
        loyalty_points_redeemed = 0
        total_loyalty_discount = Decimal('0.00')
        loyalty_points_balance = 0
        loyalty_tier = None

        if user and user.is_authenticated:
            try:
                loyalty_account, _ = LoyaltyAccount.objects.get_or_create(user=user)
                loyalty_points_balance = loyalty_account.points_balance
                loyalty_tier = loyalty_account.tier

                pre_loyalty_order_total = max(Decimal('0.00'), overall_subtotal - total_coupon_discount)
                if redeem_points > 0 and pre_loyalty_order_total > Decimal('0.00') and loyalty_points_balance > 0:
                    max_points_needed = int(pre_loyalty_order_total * LoyaltyAccount.POINTS_PER_BDT)
                    loyalty_points_redeemed = min(redeem_points, loyalty_points_balance, max_points_needed)
                    total_loyalty_discount = (
                        Decimal(loyalty_points_redeemed) / Decimal(LoyaltyAccount.POINTS_PER_BDT)
                    ).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            except Exception:
                pass

        # Distribute loyalty discount proportionally based on vendor pre-loyalty subtotal
        pre_loyalty_totals = {
            v_id: max(Decimal('0.00'), v_data['subtotal'] - v_data['coupon_discount'])
            for v_id, v_data in vendor_groups.items()
        }
        sum_pre_loyalty = sum(pre_loyalty_totals.values())
        allocated_loyalty_sum = Decimal('0.00')
        highest_pre_vid = None
        max_pre = Decimal('-1.00')

        for v_id, v_data in vendor_groups.items():
            pre_amt = pre_loyalty_totals[v_id]
            if pre_amt > max_pre:
                max_pre = pre_amt
                highest_pre_vid = v_id

            if sum_pre_loyalty > Decimal('0.00') and total_loyalty_discount > Decimal('0.00'):
                share = (pre_amt / sum_pre_loyalty) * total_loyalty_discount
                v_loyalty = share.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            else:
                v_loyalty = Decimal('0.00')

            v_data['loyalty_discount'] = v_loyalty
            allocated_loyalty_sum += v_loyalty

        if highest_pre_vid is not None and allocated_loyalty_sum != total_loyalty_discount:
            diff = total_loyalty_discount - allocated_loyalty_sum
            vendor_groups[highest_pre_vid]['loyalty_discount'] += diff

        # 4. Finalize Package Totals & Shipping
        vendor_packages = []
        overall_shipping = Decimal('0.00')
        overall_total = Decimal('0.00')

        for v_id, v_data in vendor_groups.items():
            shipping = v_data['shipping_fee']
            pkg_subtotal = v_data['subtotal']
            pkg_coupon_discount = v_data['coupon_discount']
            pkg_loyalty_discount = v_data['loyalty_discount']

            pkg_total = max(
                Decimal('0.00'),
                pkg_subtotal - pkg_coupon_discount - pkg_loyalty_discount + shipping
            ).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

            overall_shipping += shipping
            overall_total += pkg_total

            vendor_packages.append({
                'vendor_id': v_id,
                'store_name': v_data['store_name'],
                'items_count': len(v_data['items']),
                'subtotal': str(pkg_subtotal),
                'coupon_discount': str(pkg_coupon_discount),
                'loyalty_discount': str(pkg_loyalty_discount),
                'shipping_fee': str(shipping),
                'total': str(pkg_total),
                'items': [
                    {
                        'product_id': itm['product_id'],
                        'product_name': itm['product_name'],
                        'variant_id': itm['variant_id'],
                        'variant_name': itm['variant_name'],
                        'sku': itm['sku'],
                        'unit_price': str(itm['unit_price']),
                        'quantity': itm['quantity'],
                        'line_total': str(itm['line_total']),
                        'image_url': itm['image_url'],
                    }
                    for itm in v_data['items']
                ],
            })

        # 5. Customer Wallet Applied & Payable Calculation
        user_wallet_balance = Decimal('0.00')
        wallet_amount_applied = Decimal('0.00')
        if user and user.is_authenticated:
            user_wallet_balance = (getattr(user, 'wallet_balance', None) or Decimal('0.00')).quantize(Decimal('0.01'))

        if use_wallet and user_wallet_balance > Decimal('0.00') and overall_total > Decimal('0.00'):
            if requested_wallet_amount is not None:
                wallet_amount_applied = min(requested_wallet_amount, user_wallet_balance, overall_total)
            else:
                wallet_amount_applied = min(user_wallet_balance, overall_total)
            wallet_amount_applied = wallet_amount_applied.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        payable_amount = max(Decimal('0.00'), overall_total - wallet_amount_applied).quantize(
            Decimal('0.01'), rounding=ROUND_HALF_UP
        )
        is_fully_covered_by_wallet = bool(use_wallet and payable_amount == Decimal('0.00') and overall_total > Decimal('0.00'))

        return {
            'subtotal': str(overall_subtotal),
            'discount': str(total_coupon_discount),
            'loyalty_points_redeemed': loyalty_points_redeemed,
            'loyalty_discount': str(total_loyalty_discount),
            'loyalty_points_balance': loyalty_points_balance,
            'loyalty_tier': loyalty_tier,
            'shipping': str(overall_shipping),
            'tax': "0.00",
            'total': str(overall_total),
            'user_wallet_balance': str(user_wallet_balance),
            'wallet_amount_applied': str(wallet_amount_applied),
            'payable_amount': str(payable_amount),
            'is_fully_covered_by_wallet': is_fully_covered_by_wallet,
            'coupon_label': coupon_label,
            'coupon_obj': coupon,
            'vendor_packages': vendor_packages,
            'internal_vendor_groups': vendor_groups,
            'stock_warnings': stock_warnings,
        }

    @classmethod
    def place_multi_vendor_order(
        cls,
        user,
        address: Address,
        items_data: List[Dict[str, Any]],
        payment_method: str,
        coupon_code: Optional[str] = None,
        redeem_points: int = 0,
        use_wallet: bool = False,
        requested_wallet_amount: Optional[Decimal] = None,
        idempotency_key: Optional[str] = None,
    ):
        """
        Creates the parent Order and vendor-specific SubOrders atomically,
        allocating exact financial amounts to each SubOrder.
        """
        from orders.models import Order, SubOrder, OrderItem

        with transaction.atomic():
            user_locked = user.__class__.objects.select_for_update().get(id=user.id)
            wallet_bal = user_locked.wallet_balance or Decimal('0.00')

            quote = cls.compute_multi_vendor_quote(
                items_data=items_data,
                coupon_code=coupon_code,
                redeem_points=redeem_points,
                user=user_locked,
                use_wallet=use_wallet,
                requested_wallet_amount=requested_wallet_amount,
            )

            if quote['stock_warnings']:
                first_warn = quote['stock_warnings'][0]
                raise ValueError(
                    f"Not enough stock for '{first_warn['product_name']}'. "
                    f"Requested: {first_warn['requested']}, Available: {first_warn['available']}"
                )

            total = Decimal(quote['total'])
            subtotal = Decimal(quote['subtotal'])
            discount_amount = Decimal(quote['discount'])
            loyalty_discount_amount = Decimal(quote['loyalty_discount'])
            shipping_fee = Decimal(quote['shipping'])
            wallet_to_apply = Decimal(quote['wallet_amount_applied'])
            loyalty_points_to_redeem = quote['loyalty_points_redeemed']

            # Determine payment status
            if wallet_to_apply >= total and total > 0:
                final_payment_method = Order.PaymentMethod.WALLET
                final_payment_status = Order.PaymentStatus.PAID
                final_order_status = Order.Status.PAID
            else:
                final_payment_method = payment_method
                final_payment_status = Order.PaymentStatus.UNPAID
                final_order_status = Order.Status.PENDING

            # Create Master Order
            order = Order.objects.create(
                customer=user_locked,
                delivery_address=address,
                coupon=quote['coupon_obj'],
                subtotal_amount=subtotal,
                discount_amount=discount_amount,
                loyalty_points_redeemed=loyalty_points_to_redeem,
                loyalty_discount_amount=loyalty_discount_amount,
                shipping_fee=shipping_fee,
                total_amount=total,
                wallet_amount_applied=wallet_to_apply,
                status=final_order_status,
                payment_method=final_payment_method,
                payment_status=final_payment_status,
                idempotency_key=idempotency_key if idempotency_key else None,
            )

            # Deduct loyalty points
            if loyalty_points_to_redeem > 0:
                loyalty_account, _ = LoyaltyAccount.objects.select_for_update().get_or_create(user=user_locked)
                loyalty_account.redeem_points(loyalty_points_to_redeem, order=order)

            # Deduct wallet balance
            if wallet_to_apply > 0:
                user_locked.wallet_balance = (wallet_bal - wallet_to_apply).quantize(Decimal('0.01'))
                user_locked.save(update_fields=['wallet_balance'])
                CustomerWalletTransaction.objects.create(
                    user=user_locked,
                    amount=wallet_to_apply,
                    transaction_type=CustomerWalletTransaction.TransactionType.DEBIT,
                    description=f"Multi-vendor payment for Order #{order.id}",
                )

            # Create vendor SubOrders with their specific financial shares
            for pkg in quote['vendor_packages']:
                vendor_id = pkg['vendor_id']
                v_data = quote['internal_vendor_groups'][vendor_id]
                vendor = v_data['vendor']

                sub_order = SubOrder.objects.create(
                    order=order,
                    vendor=vendor,
                    status=final_order_status,
                    subtotal_amount=Decimal(pkg['subtotal']),
                    discount_amount=Decimal(pkg['coupon_discount']),
                    loyalty_discount_amount=Decimal(pkg['loyalty_discount']),
                    shipping_fee=Decimal(pkg['shipping_fee']),
                    total_amount=Decimal(pkg['total']),
                    ship_by_date=timezone.now() + timezone.timedelta(hours=48),
                )

                # Deduct inventory & create line items
                for itm in v_data['items']:
                    variant = itm['variant']
                    product = itm['product']
                    qty = itm['quantity']

                    if variant:
                        variant.stock_on_hand -= qty
                        variant.save(update_fields=['stock_on_hand'])
                    else:
                        product.stock_quantity -= qty
                        product.save(update_fields=['stock_quantity'])

                    OrderItem.objects.create(
                        sub_order=sub_order,
                        product=product,
                        variant=variant,
                        quantity=qty,
                        product_title=itm['product_name'],
                        variant_name=itm['variant_name'],
                        sku=itm['sku'],
                        unit_price=itm['unit_price'],
                        image_url=itm['image_url'],
                    )

            # Award loyalty reward points for cash/payable portion
            if order.total_amount > 0:
                try:
                    loyalty_acc, _ = LoyaltyAccount.objects.get_or_create(user=user_locked)
                    loyalty_acc.earn_points_for_purchase(order.total_amount, order=order)
                except Exception:
                    pass

        # Dispatches Notifications
        cls._send_order_notifications(order)
        return order

    @classmethod
    def initiate_combined_payment(cls, order, channel: str) -> Dict[str, Any]:
        """
        Initiates a single combined transaction payment for the entire order
        (covering all vendor sub-orders in a single payment step).
        Supports BKASH, NAGAD, and ONLINE (SSLCommerz).
        """
        payable = order.payable_amount
        if payable <= Decimal('0.00'):
            raise ValueError("No payable amount left for this order.")

        channel_upper = (channel or order.payment_method or 'ONLINE').upper()

        if channel_upper == 'BKASH':
            tran_id = f"TRX-BKASH-{order.id}-{uuid.uuid4().hex[:8].upper()}"
            order.transaction_id = tran_id
            order.save(update_fields=['transaction_id'])

            checkout_url = f"/api/orders/{order.id}/pay/mfs/simulate/?channel=BKASH&tran_id={tran_id}"
            return {
                'channel': 'BKASH',
                'gateway': 'bKash Direct Checkout',
                'transaction_id': tran_id,
                'order_id': order.id,
                'amount': str(payable),
                'currency': 'BDT',
                'checkout_url': checkout_url,
                'suborders_count': order.sub_orders.count(),
                'status': 'INITIATED',
                'instructions': 'Confirm single bKash payment to disburse all sub-orders simultaneously.',
            }

        elif channel_upper == 'NAGAD':
            tran_id = f"TRX-NAGAD-{order.id}-{uuid.uuid4().hex[:8].upper()}"
            order.transaction_id = tran_id
            order.save(update_fields=['transaction_id'])

            checkout_url = f"/api/orders/{order.id}/pay/mfs/simulate/?channel=NAGAD&tran_id={tran_id}"
            return {
                'channel': 'NAGAD',
                'gateway': 'Nagad Direct Checkout',
                'transaction_id': tran_id,
                'order_id': order.id,
                'amount': str(payable),
                'currency': 'BDT',
                'checkout_url': checkout_url,
                'suborders_count': order.sub_orders.count(),
                'status': 'INITIATED',
                'instructions': 'Confirm single Nagad payment to disburse all sub-orders simultaneously.',
            }

        else:
            # Fallback to SSLCommerz payment session
            from sslcommerz_lib import SSLCOMMERZ
            settings_env = {
                'store_id': getattr(settings, 'SSLCOMMERZ_STORE_ID', 'testbox'),
                'store_pass': getattr(settings, 'SSLCOMMERZ_STORE_PASS', 'qwerty'),
                'issandbox': getattr(settings, 'SSLCOMMERZ_IS_SANDBOX', True),
            }
            sslcz = SSLCOMMERZ(settings_env)

            tran_id = f"ORDER_{order.id}_{uuid.uuid4().hex[:8].upper()}"
            order.transaction_id = tran_id
            order.save(update_fields=['transaction_id'])

            post_body = {
                'total_amount': str(payable),
                'currency': 'BDT',
                'tran_id': tran_id,
                'success_url': '/api/orders/payment/success/',
                'fail_url': '/api/orders/payment/fail/',
                'cancel_url': '/api/orders/payment/cancel/',
                'cus_name': order.customer.username,
                'cus_email': order.customer.email or 'customer@example.com',
                'cus_phone': order.delivery_address.phone_number if order.delivery_address else '01700000000',
                'cus_add1': order.delivery_address.address_line if order.delivery_address else 'Dhaka',
                'cus_city': order.delivery_address.city if order.delivery_address else 'Dhaka',
                'cus_country': 'Bangladesh',
                'shipping_method': 'NO',
                'product_name': f"Multi-Vendor Order #{order.id}",
                'product_category': 'General',
                'product_profile': 'general',
            }

            try:
                response = sslcz.createSession(post_body) or {}
                gateway_url = response.get('GatewayPageURL') or ''
            except Exception:
                gateway_url = f"/api/orders/{order.id}/pay/simulate/?tran_id={tran_id}"

            return {
                'channel': 'ONLINE',
                'gateway': 'SSLCommerz Gateway',
                'transaction_id': tran_id,
                'order_id': order.id,
                'amount': str(payable),
                'currency': 'BDT',
                'checkout_url': gateway_url,
                'suborders_count': order.sub_orders.count(),
                'status': 'INITIATED',
            }

    @classmethod
    def confirm_combined_payment(
        cls,
        order,
        transaction_id: str,
        gateway_channel: str,
        bank_tran_id: Optional[str] = None,
        val_id: Optional[str] = None,
    ) -> bool:
        """
        Marks order as PAID, transitions all sub-orders to PAID,
        creates vendor settlement records, and notifies vendors.
        """
        from orders.models import Order
        from vendors.models import SettlementRecord

        with transaction.atomic():
            order.payment_status = Order.PaymentStatus.PAID
            order.status = Order.Status.PAID
            order.transaction_id = transaction_id
            if bank_tran_id:
                order.bank_tran_id = bank_tran_id
            if val_id:
                order.val_id = val_id
            order.save()

            # Advance all sub-orders to PAID
            order.sub_orders.filter(status=Order.Status.PENDING).update(status=Order.Status.PAID)

            # Create or update SettlementRecords for each vendor
            for so in order.sub_orders.select_related('vendor'):
                commission_rate = getattr(so.vendor, 'commission_rate', Decimal('0.10'))
                gross = so.subtotal_amount - so.discount_amount
                platform_fee = (gross * commission_rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
                net = gross - platform_fee

                SettlementRecord.objects.get_or_create(
                    sub_order=so,
                    defaults={
                        'vendor': so.vendor,
                        'gross_amount': gross,
                        'platform_fee': platform_fee,
                        'net_amount': net,
                        'status': SettlementRecord.Status.PENDING,
                        'settlement_date': (timezone.now() + timezone.timedelta(days=7)).date(),
                    },
                )

        # Notify vendors of paid orders
        cls._send_order_notifications(order)
        return True

    @classmethod
    def _send_order_notifications(cls, order):
        try:
            from notifications.models import Notification
            from notifications.services import NotificationService

            NotificationService.create(
                user=order.customer,
                title='Multi-Vendor Order Confirmed',
                body=f'Your order #{order.id} across {order.sub_orders.count()} vendor packages has been confirmed.',
                event_type=Notification.Type.ORDER_PLACED,
                category=Notification.Category.TRANSACTIONAL,
                deeplink=f'app://orders/{order.id}',
                data={'order_id': str(order.id)},
                inbox_visible=True,
                push_enabled=True,
            )

            if order.payment_status == order.PaymentStatus.PAID or order.payment_method in [order.PaymentMethod.COD, order.PaymentMethod.WALLET]:
                for so in order.sub_orders.select_related('vendor__user'):
                    NotificationService.create(
                        user=so.vendor.user,
                        title='New Multi-Vendor SubOrder',
                        body=f'You received SubOrder #{so.id} from Order #{order.id} (৳{so.total_amount}).',
                        event_type=Notification.Type.NEW_SUBORDER,
                        category=Notification.Category.TRANSACTIONAL,
                        deeplink=f'app://vendor/orders/{so.id}',
                        data={'order_id': str(order.id), 'suborder_id': str(so.id)},
                        inbox_visible=True,
                        push_enabled=True,
                    )
        except Exception:
            pass
