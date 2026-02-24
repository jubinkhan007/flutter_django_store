# ═══════════════════════════════════════════════════════════════════
# VENDORS VIEWS
# ═══════════════════════════════════════════════════════════════════

from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from django.db.models import Sum, Count, Q
from .models import Vendor, WalletTransaction, PayoutRequest, BulkJob
from .serializers import VendorSerializer, WalletTransactionSerializer, PayoutRequestSerializer, BulkJobSerializer
from rest_framework.parsers import MultiPartParser, FormParser
from .services import process_bulk_job_async


class VendorOnboardingView(generics.CreateAPIView):
    serializer_class = VendorSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        if hasattr(request.user, 'vendor_profile'):
            return Response(
                {"error": "You already have a vendor profile."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user)

        request.user.type = 'VENDOR'
        request.user.save()

        return Response(serializer.data, status=status.HTTP_201_CREATED)


class VendorDashboardView(generics.RetrieveUpdateAPIView):
    serializer_class = VendorSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user.vendor_profile


class VendorStatsView(APIView):
    """
    GET /api/vendors/stats/
    Returns business stats for the vendor dashboard.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            vendor = request.user.vendor_profile
        except AttributeError:
            return Response(
                {"error": "You are not a vendor."},
                status=status.HTTP_403_FORBIDDEN
            )

        from orders.models import SubOrder, OrderItem

        total_products = vendor.products.count()
        total_suborders = SubOrder.objects.filter(vendor=vendor).count()
        pending_suborders = SubOrder.objects.filter(vendor=vendor, status='PENDING').count()

        from django.db.models import F, Sum, DecimalField, ExpressionWrapper
        # Revenue = sum of (unit_price * quantity) for all this vendor's order items
        revenue_expr = ExpressionWrapper(F('unit_price') * F('quantity'), output_field=DecimalField())
        revenue = OrderItem.objects.filter(sub_order__vendor=vendor).aggregate(
            total=Sum(revenue_expr)
        )['total'] or 0

        return Response({
            'total_products': total_products,
            'total_orders': total_suborders,
            'pending_orders': pending_suborders,
            'total_revenue': float(revenue),
            'wallet_balance': float(vendor.balance),
            'cancellation_rate': float(vendor.cancellation_rate),
            'late_shipment_rate': float(vendor.late_shipment_rate),
            'avg_handling_time_days': float(vendor.avg_handling_time_days),
        })


class VendorCustomersView(APIView):
    """
    GET /api/vendors/customers/
    Returns a list of unique customers who have ordered from this vendor,
    along with their total spend and order count.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            vendor = request.user.vendor_profile
        except AttributeError:
            return Response(
                {"error": "You are not a vendor."},
                status=status.HTTP_403_FORBIDDEN
            )

        from orders.models import OrderItem
        from django.db.models import F, Sum, Count, DecimalField, ExpressionWrapper

        # Find all completed or shipped orders for this vendor
        vendor_order_items = OrderItem.objects.filter(sub_order__vendor=vendor)
        
        spend_expr = ExpressionWrapper(F('unit_price') * F('quantity'), output_field=DecimalField())

        customers = vendor_order_items.values(
            'sub_order__order__customer__id',
            'sub_order__order__customer__username',
            'sub_order__order__customer__email'
        ).annotate(
            total_orders=Count('sub_order__order__id', distinct=True),
            total_spend=Sum(spend_expr)
        ).order_by('-total_spend')

        # Format the response
        result = [
            {
                'id': c['sub_order__order__customer__id'],
                'username': c['sub_order__order__customer__username'],
                'email': c['sub_order__order__customer__email'],
                'total_orders': c['total_orders'],
                'total_spend': float(c['total_spend']) if c['total_spend'] else 0.0,
            }
            for c in customers
        ]

        return Response(result)

# ═══════════════════════════════════════════════════════════════════
# LEDGER AND PAYOUTS
# ═══════════════════════════════════════════════════════════════════

class WalletTransactionListView(generics.ListAPIView):
    serializer_class = WalletTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return WalletTransaction.objects.filter(vendor=vendor).order_by('-created_at')
        except AttributeError:
            return WalletTransaction.objects.none()

class PayoutRequestListCreateView(generics.ListCreateAPIView):
    serializer_class = PayoutRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return PayoutRequest.objects.filter(vendor=vendor).order_by('-requested_at')
        except AttributeError:
            return PayoutRequest.objects.none()

    def perform_create(self, serializer):
        vendor = self.request.user.vendor_profile
        amount = serializer.validated_data['amount']
        
        if vendor.balance < amount:
            raise serializers.ValidationError("Insufficient wallet balance for this payout.")
            
        with transaction.atomic():
            # Create payout request
            payout = serializer.save(vendor=vendor)
            
            # Deduct from vendor balance
            vendor.balance -= amount
            vendor.save()
            
            # Log deduction in ledger
            WalletTransaction.objects.create(
                vendor=vendor,
                amount=amount,
                transaction_type=WalletTransaction.TransactionType.DEBIT,
                description=f"Requested Payout of {amount}",
                reference_id=f"PAYOUT_{payout.id}"
            )

# ═══════════════════════════════════════════════════════════════════
# BULK OPERATIONS
# ═══════════════════════════════════════════════════════════════════
from django.db import transaction

class BulkJobListCreateView(generics.ListCreateAPIView):
    serializer_class = BulkJobSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return BulkJob.objects.filter(vendor=vendor).order_by('-created_at')
        except AttributeError:
            return BulkJob.objects.none()

    def perform_create(self, serializer):
        vendor = self.request.user.vendor_profile
        job = serializer.save(vendor=vendor)
        # Trigger async processing
        process_bulk_job_async(job.id)

class BulkJobDetailView(generics.RetrieveAPIView):
    serializer_class = BulkJobSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return BulkJob.objects.filter(vendor=vendor)
        except AttributeError:
            return BulkJob.objects.none()


