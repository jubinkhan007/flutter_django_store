from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.db import transaction
from .models import Order, OrderItem
from .serializers import OrderSerializer, OrderCreateSerializer
from products.models import Product


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

        # ── Step 1: Validate all products and stock ──
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
                'price': product.price,  # Snapshot the price at time of purchase
            })

        # ── Step 2: Create order + items in a single transaction ──
        # transaction.atomic() ensures that if ANY step fails, NOTHING is saved.
        with transaction.atomic():
            order = Order.objects.create(
                customer=request.user,
                total_amount=total
            )

            for item_data in order_items:
                OrderItem.objects.create(order=order, **item_data)

                # Decrease stock
                product = item_data['product']
                product.stock_quantity -= item_data['quantity']
                product.save()

        # ── Step 3: Return the created order ──
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

        order.status = new_status
        order.save()
        return Response(OrderSerializer(order).data)
