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
    Server-side multi-vendor price revalidation before placing order.
    Returns pricing breakdown + vendor packages + partial coupon allocations without creating an order.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        items_data = serializer.validated_data['items']
        address_id = serializer.validated_data['address_id']
        coupon_code = (serializer.validated_data.get('coupon_code') or '').strip().upper()
        redeem_points = int(serializer.validated_data.get('redeem_points') or 0)
        use_wallet = serializer.validated_data.get('use_wallet', False)
        requested_wallet_amount = serializer.validated_data.get('wallet_amount')

        # Validate address
        from users.models import Address
        try:
            Address.objects.get(id=address_id, user=request.user)
        except Address.DoesNotExist:
            return Response(
                {"error": "Address not found or does not belong to you."},
                status=status.HTTP_400_BAD_REQUEST
            )

        from orders.split_checkout_service import MultiVendorSplitCheckoutService
        try:
            quote = MultiVendorSplitCheckoutService.compute_multi_vendor_quote(
                items_data=items_data,
                coupon_code=coupon_code,
                redeem_points=redeem_points,
                user=request.user,
                use_wallet=use_wallet,
                requested_wallet_amount=requested_wallet_amount,
            )
        except ValueError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        # Build backward-compatible items_detail
        items_detail = []
        for pkg in quote['vendor_packages']:
            for itm in pkg['items']:
                items_detail.append(itm)

        return Response({
            'subtotal': quote['subtotal'],
            'discount': quote['discount'],
            'loyalty_points_redeemed': quote['loyalty_points_redeemed'],
            'loyalty_discount': quote['loyalty_discount'],
            'loyalty_points_balance': quote['loyalty_points_balance'],
            'loyalty_tier': quote['loyalty_tier'],
            'shipping': quote['shipping'],
            'tax': quote['tax'],
            'total': quote['total'],
            'user_wallet_balance': quote['user_wallet_balance'],
            'wallet_amount_applied': quote['wallet_amount_applied'],
            'payable_amount': quote['payable_amount'],
            'is_fully_covered_by_wallet': quote['is_fully_covered_by_wallet'],
            'coupon_label': quote['coupon_label'],
            'items': items_detail,
            'vendor_packages': quote['vendor_packages'],
            'stock_warnings': quote['stock_warnings'],
        })


class CustomerPlaceOrderView(generics.CreateAPIView):
    """
    POST /api/orders/place/
    Creates multi-vendor order and vendor sub-orders with partial coupon & loyalty allocations.
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
        use_wallet = serializer.validated_data.get('use_wallet', False)
        requested_wallet_amount = serializer.validated_data.get('wallet_amount')
        redeem_points = int(serializer.validated_data.get('redeem_points') or 0)

        # Validate address
        from users.models import Address
        try:
            address = Address.objects.get(id=address_id, user=request.user)
        except Address.DoesNotExist:
            return Response(
                {"error": "Address not found or does not belong to you."},
                status=status.HTTP_400_BAD_REQUEST
            )

        from orders.split_checkout_service import MultiVendorSplitCheckoutService
        try:
            order = MultiVendorSplitCheckoutService.place_multi_vendor_order(
                user=request.user,
                address=address,
                items_data=items_data,
                payment_method=payment_method,
                coupon_code=coupon_code,
                redeem_points=redeem_points,
                use_wallet=use_wallet,
                requested_wallet_amount=requested_wallet_amount,
                idempotency_key=idempotency_key,
            )
        except ValueError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

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

        if order.status not in [Order.Status.PENDING, Order.Status.PAID]:
            return Response({"error": "Only PENDING or PAID orders can be cancelled."}, status=status.HTTP_400_BAD_REQUEST)

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
    refunded_wallet = False
    if order.wallet_amount_applied > 0:
        customer = order.customer
        customer.wallet_balance = (customer.wallet_balance or Decimal('0.00')) + order.wallet_amount_applied
        customer.save(update_fields=['wallet_balance'])
        try:
            from users.models import CustomerWalletTransaction
            CustomerWalletTransaction.objects.create(
                user=customer,
                amount=order.wallet_amount_applied,
                transaction_type=CustomerWalletTransaction.TransactionType.CREDIT,
                description=f"Refund for cancelled Order #{order.id}",
            )
        except Exception:
            pass
        order.wallet_amount_applied = Decimal('0.00')
        refunded_wallet = True

    if getattr(order, 'loyalty_points_redeemed', 0) > 0:
        try:
            from loyalty.models import LoyaltyAccount, LoyaltyTransaction
            account = LoyaltyAccount.objects.get(user=order.customer)
            pts = order.loyalty_points_redeemed
            account.points_balance += pts
            account.lifetime_points_redeemed = max(0, account.lifetime_points_redeemed - pts)
            account.save(update_fields=['points_balance', 'lifetime_points_redeemed', 'updated_at'])
            LoyaltyTransaction.objects.create(
                account=account,
                transaction_type=LoyaltyTransaction.Type.REFUND,
                points=pts,
                balance_after=account.points_balance,
                order=order,
                description=f"Points refunded for cancelled Order #{order.id}",
            )
            order.loyalty_points_redeemed = 0
            order.loyalty_discount_amount = Decimal('0.00')
            order.save(update_fields=['loyalty_points_redeemed', 'loyalty_discount_amount'])
        except Exception:
            pass

    if order.payment_status == Order.PaymentStatus.PAID and order.val_id:
        order.payment_status = Order.PaymentStatus.REFUNDED
        order.save()
    elif order.payment_status == Order.PaymentStatus.PAID and order.payment_method == Order.PaymentMethod.WALLET:
        order.payment_status = Order.PaymentStatus.REFUNDED
        order.save()
    elif refunded_wallet:
        order.save(update_fields=['wallet_amount_applied'])


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
    Either:
      - Manual: mark sub-order as SHIPPED and attach courier details, OR
      - Automated: request courier provisioning (async) and return provision_status.
    """
    permission_classes = [IsVendorPackerOrAbove]

    def get_queryset(self):
        return SubOrder.objects.filter(vendor=self.request.vendor)

    def post(self, request, pk, *args, **kwargs):
        try:
            sub_order = self.get_queryset().get(id=pk)
        except SubOrder.DoesNotExist:
            return Response({"error": "SubOrder not found."}, status=status.HTTP_404_NOT_FOUND)

        auto_provision = bool(request.data.get('auto_provision') is True or str(request.data.get('auto_provision')).lower() in ('1', 'true', 'yes'))
        courier_code = request.data.get('courier_code', '').strip().lower()

        if auto_provision:
            if not courier_code:
                return Response({"error": "courier_code is required for auto provisioning."}, status=status.HTTP_400_BAD_REQUEST)
            if sub_order.status in [Order.Status.CANCELED, Order.Status.DELIVERED]:
                return Response({"error": "Cannot provision this order."}, status=status.HTTP_400_BAD_REQUEST)

            mode = (request.data.get('mode') or 'SANDBOX').upper()
            provision_request = dict(request.data.get('provision_request') or {})
            # Allow common fields at root for convenience.
            for key in [
                'store_id',
                'recipient_city',
                'recipient_zone',
                'recipient_area',
                'item_weight',
                'item_type',
                'delivery_type',
                'special_instruction',
            ]:
                if key in request.data and key not in provision_request:
                    provision_request[key] = request.data.get(key)

            sub_order.provision_status = SubOrder.ProvisionStatus.REQUESTED
            sub_order.courier_code = courier_code
            sub_order.last_error = ''
            sub_order.provision_request = provision_request
            sub_order.save(update_fields=['provision_status', 'courier_code', 'last_error', 'provision_request', 'updated_at'])

            try:
                from logistics.tasks import provision_suborder_task

                provision_suborder_task.delay(sub_order.id, mode=mode)
            except Exception:
                pass

            return Response(SubOrderSerializer(sub_order, context={'request': request}).data)

        courier_name = request.data.get('courier_name', '').strip()
        tracking_number = request.data.get('tracking_number', '').strip()
        tracking_url = request.data.get('tracking_url', '').strip()

        if not courier_name or not tracking_number:
            return Response({"error": "courier_name and tracking_number are required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            sub_order.advance_status(Order.Status.SHIPPED)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        sub_order.courier_name = courier_name
        sub_order.tracking_number = tracking_number
        sub_order.tracking_url = tracking_url
        sub_order.courier_code = courier_code
        sub_order.provision_status = SubOrder.ProvisionStatus.CREATED
        sub_order.courier_reference_id = tracking_number
        sub_order.last_error = ''
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

        # Customer notification: ORDER_SHIPPED
        try:
            from notifications.models import Notification
            from notifications.services import NotificationService

            NotificationService.create(
                user=sub_order.order.customer,
                title='Order shipped',
                body=f'Your order #{sub_order.order.id} has been shipped.',
                event_type=Notification.Type.ORDER_SHIPPED,
                category=Notification.Category.TRANSACTIONAL,
                deeplink=f'app://orders/{sub_order.order.id}?sub_id={sub_order.id}',
                data={'order_id': str(sub_order.order.id), 'suborder_id': str(sub_order.id), 'status': 'SHIPPED'},
                inbox_visible=True,
                push_enabled=True,
            )
        except Exception:
            pass

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
        if external_id and ShipmentEvent.objects.filter(sub_order=sub_order, external_event_id=external_id).exists():
            existing = ShipmentEvent.objects.get(sub_order=sub_order, external_event_id=external_id)
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
# MULTI-VENDOR COMBINED PAYMENT VIEWS (bKash / Nagad / SSLCommerz)
# ═══════════════════════════════════════════════════════════════════

class CombinedPaymentInitiateView(generics.GenericAPIView):
    """
    POST /api/orders/<id>/pay/combined/
    Initiates single transaction payment covering all multi-vendor sub-orders.
    Body: {"channel": "BKASH" | "NAGAD" | "ONLINE"}
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            order = Order.objects.get(id=pk, customer=request.user)
        except Order.DoesNotExist:
            return Response({"error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({"error": "Order is already paid."}, status=status.HTTP_400_BAD_REQUEST)

        channel = request.data.get('channel') or order.payment_method
        from orders.split_checkout_service import MultiVendorSplitCheckoutService
        try:
            res = MultiVendorSplitCheckoutService.initiate_combined_payment(order, channel=channel)
            return Response(res, status=status.HTTP_200_OK)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


class CombinedPaymentConfirmView(generics.GenericAPIView):
    """
    POST /api/orders/<id>/pay/combined/confirm/
    Confirms single transaction bKash/Nagad/SSLCommerz payment,
    transitioning master Order and all vendor SubOrders to PAID.
    Body: {"transaction_id": "...", "channel": "BKASH" | "NAGAD" | "ONLINE"}
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            order = Order.objects.get(id=pk, customer=request.user)
        except Order.DoesNotExist:
            return Response({"error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({
                "message": "Order is already confirmed as paid.",
                "order": OrderSerializer(order).data,
            }, status=status.HTTP_200_OK)

        transaction_id = request.data.get('transaction_id') or order.transaction_id
        channel = request.data.get('channel') or order.payment_method
        bank_tran_id = request.data.get('bank_tran_id')
        val_id = request.data.get('val_id')

        if not transaction_id:
            import uuid
            transaction_id = f"TRX-{channel.upper()}-{order.id}-{uuid.uuid4().hex[:6].upper()}"

        from orders.split_checkout_service import MultiVendorSplitCheckoutService
        MultiVendorSplitCheckoutService.confirm_combined_payment(
            order=order,
            transaction_id=transaction_id,
            gateway_channel=channel,
            bank_tran_id=bank_tran_id,
            val_id=val_id,
        )

        return Response({
            "message": "Multi-vendor combined payment confirmed successfully.",
            "order": OrderSerializer(order).data,
        }, status=status.HTTP_200_OK)


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

        if order.payment_method in [Order.PaymentMethod.COD, Order.PaymentMethod.WALLET]:
            return Response(
                {"error": f"{order.get_payment_method_display()} orders cannot be paid online."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.payment_status == Order.PaymentStatus.PAID:
            return Response({"error": "Order is already paid."}, status=status.HTTP_400_BAD_REQUEST)

        net_payable = order.payable_amount
        if net_payable <= 0:
            return Response({"error": "No remaining balance to pay online."}, status=status.HTTP_400_BAD_REQUEST)

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
        post_body['total_amount'] = str(net_payable)
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

        # sslcommerz_lib may return None (or raise) on network/auth issues.
        try:
            response = sslcz.createSession(post_body)
        except Exception as exc:
            return Response(
                {
                    "error": "Failed to initiate payment.",
                    "details": str(exc),
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        if not isinstance(response, dict):
            return Response(
                {
                    "error": "Failed to initiate payment.",
                    "details": {"raw": str(response)},
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        if response.get('status') == 'SUCCESS' and response.get('GatewayPageURL'):
            return Response({"GatewayPageURL": response['GatewayPageURL']})

        return Response(
            {"error": "Failed to initiate payment.", "details": response},
            status=status.HTTP_502_BAD_GATEWAY,
        )


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

                    # Vendor notification: NEW_SUBORDER (ONLINE payment confirmed).
                    try:
                        from notifications.models import Notification
                        from notifications.services import NotificationService

                        for so in order.sub_orders.select_related('vendor__user').all():
                            NotificationService.create(
                                user=so.vendor.user,
                                title='New paid order',
                                body=f'You have a new paid order (SubOrder #{so.id}).',
                                event_type=Notification.Type.NEW_SUBORDER,
                                category=Notification.Category.TRANSACTIONAL,
                                deeplink=f'app://vendor/orders/{so.id}',
                                data={'order_id': str(order.id), 'suborder_id': str(so.id), 'status': 'PAID'},
                                inbox_visible=True,
                                push_enabled=True,
                            )
                    except Exception:
                        pass

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
        if tran_id:
            try:
                order = Order.objects.get(transaction_id=tran_id)
                if order.payment_status != Order.PaymentStatus.PAID:
                    order.status = Order.Status.CANCELED
                    order.save()
                    order.sub_orders.update(status=Order.Status.CANCELED, canceled_at=timezone.now())
                    process_refund_if_paid(order)
            except Order.DoesNotExist:
                pass

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
        if tran_id:
            try:
                order = Order.objects.get(transaction_id=tran_id)
                if order.payment_status != Order.PaymentStatus.PAID:
                    order.status = Order.Status.CANCELED
                    order.save()
                    order.sub_orders.update(status=Order.Status.CANCELED, canceled_at=timezone.now())
                    process_refund_if_paid(order)
            except Order.DoesNotExist:
                pass

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


class OrderInvoicePDFView(generics.GenericAPIView):
    """
    GET /api/orders/<pk>/invoice/pdf/
    Generates and returns an official branded PDF tax invoice.
    Supports Bearer header OR ?token=<jwt> query parameter for direct download links.
    Allowed for:
      - The customer who placed the order
      - A vendor whose store fulfills any sub-order in the order
      - Platform staff / admin
    """
    permission_classes = []

    def get(self, request, pk, *args, **kwargs):
        from django.http import HttpResponse
        from django.contrib.auth import get_user_model
        from rest_framework_simplejwt.tokens import AccessToken
        from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
        from .invoice_service import OrderInvoiceService

        # 1. Resolve user from request.user OR query param 'token'
        user = request.user if (request.user and request.user.is_authenticated) else None
        
        if not user:
            token_str = request.query_params.get('token')
            if token_str:
                User = get_user_model()
                try:
                    validated_token = AccessToken(token_str)
                    user_id = validated_token.get('user_id')
                    user = User.objects.get(id=user_id)
                except (InvalidToken, TokenError, User.DoesNotExist):
                    return Response({"error": "Invalid or expired download token."}, status=status.HTTP_401_UNAUTHORIZED)

        if not user:
            return Response({"error": "Authentication required to download invoice."}, status=status.HTTP_401_UNAUTHORIZED)

        # 2. Fetch order with deep relationships
        try:
            order = Order.objects.select_related('customer', 'delivery_address', 'coupon').prefetch_related(
                'sub_orders', 'sub_orders__vendor', 'sub_orders__items',
                'sub_orders__items__product', 'sub_orders__items__variant'
            ).get(id=pk)
        except Order.DoesNotExist:
            return Response({"error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        # 3. Check permissions
        is_customer = (order.customer_id == user.id)
        is_staff = user.is_staff or getattr(user, 'type', None) == 'ADMIN'
        is_vendor = order.sub_orders.filter(vendor__user=user).exists()

        if not (is_customer or is_staff or is_vendor):
            return Response({"error": "You do not have permission to view this invoice."}, status=status.HTTP_403_FORBIDDEN)

        # 4. Generate PDF
        try:
            pdf_bytes = OrderInvoiceService.generate_invoice_pdf(order)
        except Exception as e:
            return Response({"error": f"Failed to generate invoice PDF: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        filename = f"invoice_order_{order.id}.pdf"
        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        response['Content-Disposition'] = f'inline; filename="{filename}"'
        response['X-Invoice-Number'] = f"INV-{order.id:06d}"
        return response


class OrderInvoiceVerifyView(generics.GenericAPIView):
    """
    GET /api/orders/<pk>/invoice/verify/
    Public verification endpoint to authenticate scanned invoice QR codes.
    """
    permission_classes = []

    def get(self, request, pk, *args, **kwargs):
        try:
            order = Order.objects.select_related('customer').get(id=pk)
        except Order.DoesNotExist:
            return Response({"valid": False, "error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            "valid": True,
            "invoice_number": f"INV-{order.id:06d}-{order.created_at.strftime('%Y%m%d')}",
            "order_id": order.id,
            "order_date": order.created_at.isoformat(),
            "customer_name": order.customer.get_full_name() or order.customer.username,
            "total_amount": str(order.total_amount),
            "payable_amount": str(order.payable_amount),
            "payment_status": order.payment_status,
            "order_status": order.status,
            "sub_orders_count": order.sub_orders.count(),
            "verification_timestamp": timezone.now().isoformat(),
        }, status=status.HTTP_200_OK)

