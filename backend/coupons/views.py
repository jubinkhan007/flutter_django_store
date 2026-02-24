from decimal import Decimal

from django.db.models import Q
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from products.models import Product

from .models import Coupon
from .serializers import CouponAvailableSerializer, CouponValidateSerializer, PublicCouponSerializer, VendorCouponSerializer
from .services import compute_coupon_discount


class CouponListView(generics.ListAPIView):
    """
    GET /api/coupons/

    Default: lists active GLOBAL coupons (admin coupons applicable to all shops).

    Optional query params:
      - scope=GLOBAL|VENDOR (default GLOBAL)
      - vendor_id=<int> (required for scope=VENDOR)
    """

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PublicCouponSerializer

    def get_queryset(self):
        qs = Coupon.objects.filter(is_active=True).order_by('-created_at')

        scope = (self.request.query_params.get('scope') or Coupon.Scope.GLOBAL).strip().upper()
        if scope not in {Coupon.Scope.GLOBAL, Coupon.Scope.VENDOR}:
            scope = Coupon.Scope.GLOBAL

        if scope == Coupon.Scope.VENDOR:
            vendor_id = self.request.query_params.get('vendor_id')
            if not vendor_id:
                return Coupon.objects.none()
            return qs.filter(scope=Coupon.Scope.VENDOR, vendor_id=vendor_id)

        return qs.filter(scope=Coupon.Scope.GLOBAL)

class CouponAvailableView(generics.GenericAPIView):
    """
    POST /api/coupons/available/

    Body:
      { "items": [{"product": 1, "quantity": 2}, ...] }

    Returns only active coupons that produce a non-zero discount for the given cart.
    """

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = CouponAvailableSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        items_data = serializer.validated_data['items']

        order_items = []
        vendor_ids = set()
        for item in items_data:
            try:
                product = Product.objects.get(id=item['product'], is_available=True)
            except Product.DoesNotExist:
                return Response(
                    {"error": f"Product with ID {item['product']} not found or unavailable."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            qty = item['quantity']
            line_total = product.price * qty
            vendor_ids.add(product.vendor_id)
            order_items.append({'product': product, 'quantity': qty, 'line_total': line_total})

        coupons = (
            Coupon.objects.filter(is_active=True)
            .filter(Q(scope=Coupon.Scope.GLOBAL) | Q(scope=Coupon.Scope.VENDOR, vendor_id__in=vendor_ids))
            .order_by('-created_at')
        )

        results = []
        for coupon in coupons:
            computed = compute_coupon_discount(coupon=coupon, order_items=order_items)
            if not computed.get('ok'):
                continue

            discount = computed.get('discount')
            if discount is None or discount <= 0:
                continue

            results.append(
                {
                    'id': coupon.id,
                    'code': coupon.code,
                    'scope': coupon.scope,
                    'vendor_id': coupon.vendor_id,
                    'vendor_name': coupon.vendor.store_name if coupon.vendor_id else None,
                    'discount_type': coupon.discount_type,
                    'discount_value': str(coupon.discount_value),
                    'min_order_amount': str(coupon.min_order_amount) if coupon.min_order_amount is not None else None,
                    'eligible_subtotal': str(computed['eligible_subtotal']),
                    'discount': str(computed['discount']),
                    'total_after_discount': str(computed['total_after_discount']),
                }
            )

        # Highest discount first
        results.sort(key=lambda x: (Decimal(x['discount']), x['code']), reverse=True)
        return Response(results)


class CouponValidateView(generics.GenericAPIView):
    """
    POST /api/coupons/validate/

    Body:
      { "code": "SAVE10", "items": [{"product": 1, "quantity": 2}, ...] }
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = CouponValidateSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        code = serializer.validated_data['code'].strip().upper()
        items_data = serializer.validated_data['items']

        try:
            coupon = Coupon.objects.get(code=code, is_active=True)
        except Coupon.DoesNotExist:
            return Response({'error': 'Invalid coupon code.'}, status=status.HTTP_400_BAD_REQUEST)

        order_items = []
        for item in items_data:
            try:
                product = Product.objects.get(id=item['product'], is_available=True)
            except Product.DoesNotExist:
                return Response(
                    {"error": f"Product with ID {item['product']} not found or unavailable."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            qty = item['quantity']
            line_total = product.price * qty
            order_items.append({'product': product, 'quantity': qty, 'line_total': line_total})

        result = compute_coupon_discount(coupon=coupon, order_items=order_items)
        if not result['ok']:
            return Response({'error': result['error']}, status=status.HTTP_400_BAD_REQUEST)

        return Response(
            {
                'code': coupon.code,
                'scope': coupon.scope,
                'vendor_id': coupon.vendor_id,
                'subtotal': str(result['subtotal']),
                'eligible_subtotal': str(result['eligible_subtotal']),
                'discount': str(result['discount']),
                'total_after_discount': str(result['total_after_discount']),
            }
        )


class VendorCouponListCreateView(generics.ListCreateAPIView):
    """
    GET/POST /api/vendors/coupons/
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorCouponSerializer

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return Coupon.objects.none()
        return Coupon.objects.filter(scope=Coupon.Scope.VENDOR, vendor=vendor).order_by('-created_at')


class VendorCouponDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET/PATCH/DELETE /api/vendors/coupons/<id>/
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorCouponSerializer

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return Coupon.objects.none()
        return Coupon.objects.filter(scope=Coupon.Scope.VENDOR, vendor=vendor)
