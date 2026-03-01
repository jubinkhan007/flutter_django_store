from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.db import transaction
from .models import Order, SubOrder, OrderItem, ShipmentEvent
from .serializers import OrderSerializer, OrderCreateSerializer, SubOrderSerializer, ShipmentEventSerializer
from products.models import Product, ProductVariant
from coupons.models import Coupon
from coupons.services import compute_coupon_discount
from django.conf import settings
from django.utils import timezone
from sslcommerz_lib import SSLCOMMERZ
import uuid
from decimal import Decimal
from vendors.financial_service import FinancialService


# ═══════════════════════════════════════════════════════════════════
# CUSTOMER VIEWS
# ═══════════════════════════════════════════════════════════════════

class CheckoutQuoteView(generics.GenericAPIView):
    """
    POST /api/orders/quote/
    Server-side price revalidation before placing order.
    Returns pricing breakdown + stock warnings without creating an order.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        items_data = serializer.validated_data['items']
        address_id = serializer.validated_data['address_id']
        coupon_code = (serializer.validated_data.get('coupon_code') or '').strip().upper()

        # Validate address
        from users.models import Address
        try:
            Address.objects.get(id=address_id, user=request.user)
        except Address.DoesNotExist:
            return Response(
                {"error": "Address not found or does not belong to you."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate items + compute pricing
        items_detail = []
        stock_warnings = []
        subtotal = Decimal('0.00')

        for item in items_data:
            try:
                product = Product.objects.get(id=item['product'], is_available=True)
            except Product.DoesNotExist:
                return Response(
                    {"error": f"Product with ID {item['product']} not found or unavailable."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            variant = None
            available_stock = product.stock_quantity
            unit_price = product.price

            if 'variant' in item and item['variant']:
                try:
                    variant = ProductVariant.objects.get(id=item['variant'], product=product)
                    available_stock = variant.available_stock
                    unit_price = variant.effective_price
                except ProductVariant.DoesNotExist:
                    return Response(
                        {"error": f"Variant not found for product '{product.name}'."},
                        status=status.HTTP_400_BAD_REQUEST
                    )

            requested_qty = item['quantity']
            if available_stock < requested_qty:
                stock_warnings.append({
                    'product_id': product.id,
                    'product_name': product.name,
                    'variant_id': variant.id if variant else None,
                    'requested': requested_qty,
                    'available': available_stock,
                })

            line_total = unit_price * requested_qty
            subtotal += line_total

            items_detail.append({
                'product_id': product.id,
                'product_name': product.name,
                'variant_id': variant.id if variant else None,
                'unit_price': str(unit_price),
                'quantity': requested_qty,
                'line_total': str(line_total),
                'image_url': product.image.url if product.image else '',
            })

        # Coupon computation
        discount_amount = Decimal('0.00')
        coupon_label = None
        if coupon_code:
            try:
                coupon = Coupon.objects.get(code=coupon_code, is_active=True)
                order_items_compat = []
                for item in items_data:
                    prod = Product.objects.get(id=item['product'])
                    up = prod.price
                    if 'variant' in item and item['variant']:
                        vari = ProductVariant.objects.get(id=item['variant'], product=prod)
                        up = vari.effective_price
                    order_items_compat.append({
                        'product': prod, 'vendor': prod.vendor,
                        'price': up, 'unit_price': up, 'quantity': item['quantity'],
                    })
                coupon_result = compute_coupon_discount(coupon=coupon, order_items=order_items_compat)
                if coupon_result['ok']:
                    discount_amount = coupon_result['discount']
                    coupon_label = f"{coupon.code}"
            except Coupon.DoesNotExist:
                pass

        shipping = Decimal('0.00')
        tax = Decimal('0.00')
        total = (subtotal - discount_amount + shipping + tax).quantize(Decimal('0.01'))
        if total < 0:
            total = Decimal('0.00')

        return Response({
            'subtotal': str(subtotal.quantize(Decimal('0.01'))),
            'discount': str(discount_amount.quantize(Decimal('0.01'))),
            'shipping': str(shipping.quantize(Decimal('0.01'))),
            'tax': str(tax.quantize(Decimal('0.01'))),
            'total': str(total),
            'coupon_label': coupon_label,
            'items': items_detail,
            'stock_warnings': stock_warnings,
        })


class CustomerPlaceOrderView(generics.CreateAPIView):
    """
    POST /api/orders/place/
    """
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        # ── Idempotency check ──
        idempotency_key = request.headers.get('X-Idempotency-Key', '').strip()
        if idempotency_key:
            try:
                existing_order = Order.objects.get(idempotency_key=idempotency_key)
                return Response(OrderSerializer(existing_order).data, status=status.HTTP_201_CREATED)
            except Order.DoesNotExist:
                pass

        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        items_data = serializer.validated_data['items']
        address_id = serializer.validated_data['address_id']
        payment_method = serializer.validated_data.get('payment_method', Order.PaymentMethod.ONLINE)
        coupon_code = (serializer.validated_data.get('coupon_code') or '').strip().upper()

        # ── Step 1: Validate address ──
        from users.models import Address
        try:
            address = Address.objects.get(id=address_id, user=request.user)
        except Address.DoesNotExist:
            return Response(
                {"error": "Address not found or does not belong to you."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ── Step 2: Validate all products and stock ──
        order_items_payload = []
        subtotal = Decimal('0.00')
        vendors_set = set()

        for item in items_data:
            try:
                product = Product.objects.get(id=item['product'], is_available=True)
            except Product.DoesNotExist:
                return Response(
                    {"error": f"Product with ID {item['product']} not found or unavailable."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            variant = None
            if 'variant' in item and item['variant']:
                try:
                    variant = ProductVariant.objects.get(id=item['variant'], product=product)
                except ProductVariant.DoesNotExist:
                    return Response(
                        {"error": f"Variant not found for product '{product.name}'."},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # Check variant stock
                if variant.available_stock < item['quantity']:
                    return Response(
                        {"error": f"Not enough stock for variant. Available: {variant.available_stock}"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                unit_price = variant.effective_price
                sku = variant.sku
                variant_name = ", ".join([v.value for v in variant.option_values.all()])
                
            else:
                # Fallback to product stock if no variant system is used for this item
                if product.stock_quantity < item['quantity']:
                    return Response(
                        {"error": f"Not enough stock for '{product.name}'. Available: {product.stock_quantity}"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                unit_price = product.price
                sku = ""
                variant_name = ""

            line_total = unit_price * item['quantity']
            subtotal += line_total
            vendors_set.add(product.vendor)

            order_items_payload.append({
                'product': product,
                'variant': variant,
                'vendor': product.vendor,
                'quantity': item['quantity'],
                'unit_price': unit_price,
                'product_title': product.name,
                'variant_name': variant_name,
                'sku': sku,
                'image_url': product.image.url if product.image else '',
                'line_total': line_total,
            })

        coupon = None
        discount_amount = Decimal('0.00')
        if coupon_code:
            try:
                coupon = Coupon.objects.get(code=coupon_code, is_active=True)
                # Note: You'll need to adapt `compute_coupon_discount` if it relies on old OrderItem dict
                # It currently expects a dict with 'product', 'vendor', 'price', etc.
                # For compatibility we inject 'price' = 'unit_price' temporarily.
                for oi in order_items_payload:
                    oi['price'] = oi['unit_price']
                
                coupon_result = compute_coupon_discount(coupon=coupon, order_items=order_items_payload)
                if not coupon_result['ok']:
                    return Response({"error": coupon_result['error']}, status=status.HTTP_400_BAD_REQUEST)
                discount_amount = coupon_result['discount']
            except Coupon.DoesNotExist:
                return Response({"error": "Invalid coupon code."}, status=status.HTTP_400_BAD_REQUEST)

        total = (subtotal - discount_amount).quantize(Decimal('0.01'))
        if total < 0:
            total = Decimal('0.00')

        # ── Step 3: Create order + suborders + items in a single transaction ──
        with transaction.atomic():
            order = Order.objects.create(
                customer=request.user,
                delivery_address=address,
                coupon=coupon,
                subtotal_amount=subtotal,
                discount_amount=discount_amount,
                total_amount=total,
                payment_method=payment_method,
                idempotency_key=idempotency_key if idempotency_key else None,
            )

            # Create SubOrders
            sub_orders = {}
            for vendor in vendors_set:
                sub_orders[vendor.id] = SubOrder.objects.create(
                    order=order,
                    vendor=vendor,
                    ship_by_date=timezone.now() + timezone.timedelta(hours=48)
                )

            for item_data in order_items_payload:
                vendor_id = item_data['vendor'].id
                sub_order = sub_orders[vendor_id]
                
                # Decrease stock
                variant = item_data['variant']
                product = item_data['product']
                
                if variant:
                    variant.stock_on_hand -= item_data['quantity']
                    variant.save()
                else:
                    product.stock_quantity -= item_data['quantity']
                    product.save()

                OrderItem.objects.create(
                    sub_order=sub_order,
                    product=item_data['product'],
                    variant=item_data['variant'],
                    quantity=item_data['quantity'],
                    product_title=item_data['product_title'],
                    variant_name=item_data['variant_name'],
                    sku=item_data['sku'],
                    unit_price=item_data['unit_price'],
                    image_url=item_data['image_url']
                )

        # ── Step 4: Return the created order ──
        result = OrderSerializer(order).data
        return Response(result, status=status.HTTP_201_CREATED)


class CustomerOrderListView(generics.ListAPIView):
    """
    GET /api/orders/
    """
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user).order_by('-created_at')


class CustomerOrderDetailView(generics.RetrieveAPIView):
    """
    GET /api/orders/<id>/
    """
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user)

class CustomerOrderCancelView(generics.GenericAPIView):
    """
    POST /api/orders/<id>/cancel/
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            order = Order.objects.get(id=pk, customer=request.user)
        except Order.DoesNotExist:
            return Response({"error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.status != Order.Status.PENDING:
            return Response({"error": "Only PENDING orders can be cancelled."}, status=status.HTTP_400_BAD_REQUEST)

        process_refund_if_paid(order)

        order.status = Order.Status.CANCELED
        order.save()
        
        # Also cancel suborders
        order.sub_orders.update(status=Order.Status.CANCELED, canceled_at=timezone.now())
        
        return Response({"message": "Order cancelled successfully.", "order": OrderSerializer(order).data})


# ═══════════════════════════════════════════════════════════════════
# VENDOR VIEWS
# ═══════════════════════════════════════════════════════════════════
from vendors.permissions import IsVendorSupportOrAbove, IsVendorPackerOrAbove, IsVendorOwnerOrManager

class VendorOrderListView(generics.ListAPIView):
    """
    GET /api/vendors/orders/
    Returns suborders for the logged-in vendor.
    """
    from orders.serializers import SubOrderSerializer
    serializer_class = SubOrderSerializer
    permission_classes = [IsVendorSupportOrAbove]

    def get_queryset(self):
        return SubOrder.objects.filter(vendor=self.request.vendor).order_by('-created_at')


class VendorUpdateOrderStatusView(generics.UpdateAPIView):
    """
    PATCH /api/vendors/orders/<id>/
    Advances status via the state machine.
    """
    serializer_class = SubOrderSerializer
    permission_classes = [IsVendorPackerOrAbove]

    def get_queryset(self):
        return SubOrder.objects.filter(vendor=self.request.vendor)

    def partial_update(self, request, *args, **kwargs):
        sub_order = self.get_object()
        new_status = request.data.get('status')

        try:
            sub_order.advance_status(new_status)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        # Payout credit on DELIVERED
        if new_status == Order.Status.DELIVERED:
            order = sub_order.order
            if order.payment_status == Order.PaymentStatus.PAID:
                try:
                    FinancialService.accrue_earnings(sub_order)
                except Exception:
                    # Do not block order status progression if finance accrual fails.
                    # The accrual can be retried safely due to idempotency.
                    pass

        # Roll up master order status
        _recompute_master_order(sub_order.order)
        return Response(SubOrderSerializer(sub_order).data)

class VendorOrderCancelView(generics.GenericAPIView):
    """
    POST /api/vendors/orders/<id>/cancel/
    Allows vendor to cancel their SubOrder.
    """
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return SubOrder.objects.filter(vendor=self.request.vendor)

    def post(self, request, pk, *args, **kwargs):
        queryset = self.get_queryset()
        try:
            sub_order = queryset.get(id=pk)
        except SubOrder.DoesNotExist:
            return Response({"error": "SubOrder not found."}, status=status.HTTP_404_NOT_FOUND)

        if sub_order.status in [Order.Status.CANCELED, Order.Status.DELIVERED]:
            return Response({"error": "Cannot cancel this order."}, status=status.HTTP_400_BAD_REQUEST)

        # We probably shouldn't refund full order unless all suborders are canceled. 
        # But for MVP, let's just mark suborder canceled.
        sub_order.status = Order.Status.CANCELED
        sub_order.canceled_at = timezone.now()
        sub_order.save()
        
        from orders.serializers import SubOrderSerializer
        return Response({"message": "SubOrder cancelled.", "sub_order": SubOrderSerializer(sub_order).data})


def process_refund_if_paid(order):
    if order.payment_status == Order.PaymentStatus.PAID and order.val_id:
        order.payment_status = Order.PaymentStatus.REFUNDED
        order.save()


def _recompute_master_order(order):
    """Derive master Order.status from its sub-orders."""
    statuses = set(order.sub_orders.values_list('status', flat=True))
    now = timezone.now()
    if statuses == {Order.Status.DELIVERED}:
        order.status = Order.Status.DELIVERED
        order.delivered_at = now
    elif statuses == {Order.Status.CANCELED}:
        order.status = Order.Status.CANCELED
    elif Order.Status.DELIVERED in statuses:
        # Mixed — some delivered, some still in progress or cancelled
        order.status = Order.Status.SHIPPED  # best approximation for master
    elif Order.Status.SHIPPED in statuses:
        order.status = Order.Status.SHIPPED
    order.save()


class VendorSubOrderFulfillView(generics.GenericAPIView):
    """
    POST /api/vendors/sub-orders/<id>/fulfill/
    Mark the sub-order as SHIPPED and attach courier details.
    Also creates an automatic ShipmentEvent of status PICKED_UP.
    """
    permission_classes = [IsVendorPackerOrAbove]

    def get_queryset(self):
        return SubOrder.objects.filter(vendor=self.request.vendor)

    def post(self, request, pk, *args, **kwargs):
        try:
            sub_order = self.get_queryset().get(id=pk)
        except SubOrder.DoesNotExist:
            return Response({"error": "SubOrder not found."}, status=status.HTTP_404_NOT_FOUND)

        courier_name = request.data.get('courier_name', '').strip()
        tracking_number = request.data.get('tracking_number', '').strip()
        tracking_url = request.data.get('tracking_url', '').strip()
        courier_code = request.data.get('courier_code', '').strip().lower()

        try:
            sub_order.advance_status(Order.Status.SHIPPED)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        sub_order.courier_name = courier_name
        sub_order.tracking_number = tracking_number
        sub_order.tracking_url = tracking_url
        sub_order.courier_code = courier_code
        sub_order.save()

        # Auto-create a PICKED_UP shipment event
        ShipmentEvent.objects.create(
            sub_order=sub_order,
            status=ShipmentEvent.EventStatus.PICKED_UP,
            timestamp=timezone.now(),
            description=f"Order picked up by {courier_name or 'courier'}.",
            source=ShipmentEvent.Source.VENDOR,
            created_by=request.user,
            sequence=sub_order.events.count(),
        )

        _recompute_master_order(sub_order.order)
        return Response(SubOrderSerializer(sub_order, context={'request': request}).data)


class VendorSubOrderEventsView(generics.GenericAPIView):
    """
    POST /api/vendors/sub-orders/<id>/events/
    Push a new ShipmentEvent manually.
    """
    permission_classes = [IsVendorSupportOrAbove]

    def get_queryset(self):
        return SubOrder.objects.filter(vendor=self.request.vendor)

    def post(self, request, pk, *args, **kwargs):
        try:
            sub_order = self.get_queryset().get(id=pk)
        except SubOrder.DoesNotExist:
            return Response({"error": "SubOrder not found."}, status=status.HTTP_404_NOT_FOUND)

        event_status = request.data.get('status', '').strip().upper()
        valid = [s[0] for s in ShipmentEvent.EventStatus.choices]
        if event_status not in valid:
            return Response(
                {"error": f"Invalid event status. Must be one of: {valid}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        external_id = request.data.get('external_event_id') or None
        if external_id and ShipmentEvent.objects.filter(external_event_id=external_id).exists():
            existing = ShipmentEvent.objects.get(external_event_id=external_id)
            return Response(ShipmentEventSerializer(existing).data, status=status.HTTP_200_OK)

        event = ShipmentEvent.objects.create(
            sub_order=sub_order,
            status=event_status,
            location=request.data.get('location', '').strip(),
            timestamp=request.data.get('timestamp') or timezone.now(),
            description=request.data.get('description', '').strip(),
            sequence=sub_order.events.count(),
            source=request.data.get('source', ShipmentEvent.Source.VENDOR),
            created_by=request.user,
            external_event_id=external_id,
        )
        return Response(ShipmentEventSerializer(event).data, status=status.HTTP_201_CREATED)


# ═══════════════════════════════════════════════════════════════════
# SSLCOMMERZ VIEWS
# ═══════════════════════════════════════════════════════════════════

class SSLCommerzPaymentInitiateView(generics.GenericAPIView):
    """
    POST /api/orders/<id>/pay/
    Provides the GatewayPageURL to the frontend to complete payment.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            order = Order.objects.get(id=pk, customer=request.user)
        except Order.DoesNotExist:
            return Response({"error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.payment_method == Order.PaymentMethod.COD:
            return Response(
                {"error": "Cash on delivery orders cannot be paid online."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({"error": "Order is already paid."}, status=status.HTTP_400_BAD_REQUEST)

        # Initialize SSLCommerz
        settings_env = {
            'store_id': getattr(settings, 'SSLCOMMERZ_STORE_ID', 'testbox'),
            'store_pass': getattr(settings, 'SSLCOMMERZ_STORE_PASS', 'qwerty'),
            'issandbox': getattr(settings, 'SSLCOMMERZ_IS_SANDBOX', True)
        }
        sslcz = SSLCOMMERZ(settings_env)
        
        # Unique tran_id
        if not order.transaction_id:
            order.transaction_id = f"ORDER_{order.id}_{uuid.uuid4().hex[:8].upper()}"
            order.save()

        # Build req dictionary
        post_body = {}
        post_body['total_amount'] = order.total_amount
        post_body['currency'] = "BDT"
        post_body['tran_id'] = order.transaction_id
        post_body['success_url'] = request.build_absolute_uri('/api/orders/payment/success/')
        post_body['fail_url'] = request.build_absolute_uri('/api/orders/payment/fail/')
        post_body['cancel_url'] = request.build_absolute_uri('/api/orders/payment/cancel/')
        
        # Customer Info
        post_body['emi_option'] = 0
        post_body['cus_name'] = order.customer.username
        post_body['cus_email'] = order.customer.email or "test@example.com"
        
        if order.delivery_address:
            post_body['cus_phone'] = order.delivery_address.phone_number
            post_body['cus_add1'] = order.delivery_address.address_line
            post_body['cus_city'] = order.delivery_address.city
        else:
            post_body['cus_phone'] = "01700000000"
            post_body['cus_add1'] = "Dhaka"
            post_body['cus_city'] = "Dhaka"
        
        post_body['cus_country'] = "Bangladesh"
        post_body['shipping_method'] = "NO"
        
        post_body['product_name'] = f"Order #{order.id}"
        post_body['product_category'] = "General"
        post_body['product_profile'] = "general"

        response = sslcz.createSession(post_body)
        if response.get('status') == 'SUCCESS':
            return Response({"GatewayPageURL": response['GatewayPageURL']})
        else:
            return Response({"error": "Failed to initiate payment.", "details": response}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


from django.http import HttpResponse

class SSLCommerzSuccessView(generics.GenericAPIView):
    """
    POST /api/orders/payment/success/
    Webhook from SSLCommerz upon success.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        val_id = request.data.get('val_id')
        tran_id = request.data.get('tran_id')

        # Validate with SSLCommerz
        settings_env = {
            'store_id': getattr(settings, 'SSLCOMMERZ_STORE_ID', 'testbox'),
            'store_pass': getattr(settings, 'SSLCOMMERZ_STORE_PASS', 'qwerty'),
            'issandbox': getattr(settings, 'SSLCOMMERZ_IS_SANDBOX', True)
        }
        sslcz = SSLCOMMERZ(settings_env)
        
        if val_id:
            response = sslcz.validationTransactionOrder(val_id) or {}
            if response.get('status') == 'VALID' or response.get('status') == 'VALIDATED':
                try:
                    order = Order.objects.get(transaction_id=tran_id)
                    order.payment_status = Order.PaymentStatus.PAID
                    order.val_id = val_id
                    # Needed for initiating refunds via SSLCommerz refund API.
                    order.bank_tran_id = response.get('bank_tran_id') or order.bank_tran_id
                    order.save()
                    return HttpResponse(_deep_link_redirect(
                        scheme_url=f"shopease://payment/success?order_id={order.id}",
                        title='Payment Successful!',
                        color='green',
                        message='Redirecting you back to the app...',
                    ))
                except Order.DoesNotExist:
                    pass

        return HttpResponse(_deep_link_redirect(
            scheme_url='shopease://payment/fail',
            title='Payment Validation Failed',
            color='red',
            message='Redirecting you back to the app...',
        ), status=400)

class SSLCommerzFailView(generics.GenericAPIView):
    """
    POST /api/orders/payment/fail/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        tran_id = request.data.get('tran_id')
        suffix = f"?tran_id={tran_id}" if tran_id else ""
        return HttpResponse(_deep_link_redirect(
            scheme_url=f"shopease://payment/fail{suffix}",
            title='Payment Failed',
            color='red',
            message='Redirecting you back to the app...',
        ))

class SSLCommerzCancelView(generics.GenericAPIView):
    """
    POST /api/orders/payment/cancel/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        tran_id = request.data.get('tran_id')
        suffix = f"?tran_id={tran_id}" if tran_id else ""
        return HttpResponse(_deep_link_redirect(
            scheme_url=f"shopease://payment/cancel{suffix}",
            title='Payment Cancelled',
            color='orange',
            message='Redirecting you back to the app...',
        ))


def _deep_link_redirect(scheme_url: str, title: str, color: str, message: str) -> str:
    """Returns an HTML page that immediately opens the app via custom URL scheme."""
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <script>window.location.href = '{scheme_url}';</script>
</head>
<body style="font-family:sans-serif;text-align:center;padding-top:60px;">
  <h1 style="color:{color};">{title}</h1>
  <p>{message}</p>
  <p><a href="{scheme_url}" style="color:{color};">Tap here if not redirected automatically</a></p>
</body>
</html>"""
