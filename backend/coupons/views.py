from rest_framework import generics, permissions, status
from rest_framework.response import Response

from products.models import Product

from .models import Coupon
from .serializers import CouponValidateSerializer, VendorCouponSerializer
from .services import compute_coupon_discount


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

