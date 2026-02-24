from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.db import transaction
from .models import Order, OrderItem
from .serializers import OrderSerializer, OrderCreateSerializer
from products.models import Product
from vendors.models import WalletTransaction
from django.conf import settings
from sslcommerz_lib import SSLCOMMERZ
import uuid
from decimal import Decimal


# ═══════════════════════════════════════════════════════════════════
# CUSTOMER VIEWS
# ═══════════════════════════════════════════════════════════════════

class CustomerPlaceOrderView(generics.CreateAPIView):
    """
    POST /api/orders/

    A customer sends a list of products and quantities to place an order.

    Request body:
    {
        "items": [
            {"product": 1, "quantity": 2},
            {"product": 5, "quantity": 1}
        ]
    }

    The backend will:
    1. Look up each product's price and vendor
    2. Check stock availability
    3. Calculate the total
    4. Create the Order + OrderItems
    5. Decrease stock quantities
    6. Return the created order details
    """
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        items_data = serializer.validated_data['items']
        address_id = serializer.validated_data['address_id']

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
        order_items = []
        total = 0

        for item in items_data:
            try:
                product = Product.objects.get(id=item['product'], is_available=True)
            except Product.DoesNotExist:
                return Response(
                    {"error": f"Product with ID {item['product']} not found or unavailable."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if product.stock_quantity < item['quantity']:
                return Response(
                    {"error": f"Not enough stock for '{product.name}'. Available: {product.stock_quantity}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            line_total = product.price * item['quantity']
            total += line_total

            order_items.append({
                'product': product,
                'vendor': product.vendor,
                'quantity': item['quantity'],
                'price': product.price,  # Snapshot
            })

        # ── Step 3: Create order + items in a single transaction ──
        with transaction.atomic():
            order = Order.objects.create(
                customer=request.user,
                delivery_address=address,
                total_amount=total
            )

            for item_data in order_items:
                OrderItem.objects.create(order=order, **item_data)

                # Decrease stock
                product = item_data['product']
                product.stock_quantity -= item_data['quantity']
                product.save()

        # ── Step 4: Return the created order ──
        result = OrderSerializer(order).data
        return Response(result, status=status.HTTP_201_CREATED)


class CustomerOrderListView(generics.ListAPIView):
    """
    GET /api/orders/

    Returns all orders placed by the currently logged-in customer.
    """
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(customer=self.request.user).order_by('-created_at')


class CustomerOrderDetailView(generics.RetrieveAPIView):
    """
    GET /api/orders/<id>/

    Returns the detail of a specific order (only if owned by the customer).
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
        return Response({"message": "Order cancelled successfully.", "order": OrderSerializer(order).data})


# ═══════════════════════════════════════════════════════════════════
# VENDOR VIEWS
# ═══════════════════════════════════════════════════════════════════

class VendorOrderListView(generics.ListAPIView):
    """
    GET /api/vendors/orders/

    Returns all orders that contain products from the logged-in vendor.
    Vendors need this to know what to ship.
    """
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            # Get all orders that have at least one item from this vendor
            order_ids = OrderItem.objects.filter(vendor=vendor).values_list('order_id', flat=True)
            return Order.objects.filter(id__in=order_ids).order_by('-created_at')
        except AttributeError:
            return Order.objects.none()


class VendorUpdateOrderStatusView(generics.UpdateAPIView):
    """
    PATCH /api/vendors/orders/<id>/

    Allows a vendor to update the status of an order (e.g., PENDING → SHIPPED).
    Only works if the vendor has items in that order.
    """
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            order_ids = OrderItem.objects.filter(vendor=vendor).values_list('order_id', flat=True)
            return Order.objects.filter(id__in=order_ids)
        except AttributeError:
            return Order.objects.none()

    def partial_update(self, request, *args, **kwargs):
        order = self.get_object()
        new_status = request.data.get('status')

        valid_statuses = [s[0] for s in Order.Status.choices]
        if new_status not in valid_statuses:
            return Response(
                {"error": f"Invalid status. Must be one of: {valid_statuses}"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if new_status == Order.Status.DELIVERED and order.status != Order.Status.DELIVERED:
            if order.payment_status == Order.PaymentStatus.PAID:
                with transaction.atomic():
                    for item in order.items.all():
                        # 10% commission deduction -> Vendor gets 90%
                        earnings = (item.price * item.quantity) * Decimal('0.90')
                        vendor = item.vendor
                        vendor.balance += earnings
                        vendor.save()
                        
                        WalletTransaction.objects.create(
                            vendor=vendor,
                            amount=earnings,
                            transaction_type=WalletTransaction.TransactionType.CREDIT,
                            description=f"Earnings from Order #{order.id} for {item.quantity}x {item.product.name}"
                        )

        order.status = new_status
        order.save()
        return Response(OrderSerializer(order).data)

class VendorOrderCancelView(generics.GenericAPIView):
    """
    POST /api/vendors/orders/<id>/cancel/
    Allows vendor to cancel and refund an order.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            order_ids = OrderItem.objects.filter(vendor=vendor).values_list('order_id', flat=True)
            return Order.objects.filter(id__in=order_ids)
        except AttributeError:
            return Order.objects.none()

    def post(self, request, pk, *args, **kwargs):
        queryset = self.get_queryset()
        try:
            order = queryset.get(id=pk)
        except Order.DoesNotExist:
            return Response({"error": "Order not found or not mapped to you."}, status=status.HTTP_404_NOT_FOUND)

        if order.status in [Order.Status.CANCELED, Order.Status.DELIVERED]:
            return Response({"error": "Cannot cancel this order."}, status=status.HTTP_400_BAD_REQUEST)

        process_refund_if_paid(order)

        order.status = Order.Status.CANCELED
        order.save()
        return Response({"message": "Order cancelled & refunded successfully.", "order": OrderSerializer(order).data})


def process_refund_if_paid(order):
    if order.payment_status == Order.PaymentStatus.PAID and order.val_id:
        # In a real app we'd call the SSLCOMMERZ refund API using the val_id or bank_tran_id
        # SSLCOMMERZ refund API: https://sandbox.sslcommerz.com/validator/api/merchantTransIDvalidationAPI.php
        # For our purposes, we just mark it as refunded.
        order.payment_status = Order.PaymentStatus.REFUNDED
        order.save()


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
            response = sslcz.validationTransactionOrder(val_id)
            if response.get('status') == 'VALID' or response.get('status') == 'VALIDATED':
                try:
                    order = Order.objects.get(transaction_id=tran_id)
                    order.payment_status = Order.PaymentStatus.PAID
                    order.val_id = val_id
                    order.save()
                    return HttpResponse(_deep_link_redirect(
                        scheme_url='shopease://payment/success',
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
        return HttpResponse(_deep_link_redirect(
            scheme_url='shopease://payment/fail',
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
        return HttpResponse(_deep_link_redirect(
            scheme_url='shopease://payment/cancel',
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
