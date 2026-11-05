# ═══════════════════════════════════════════════════════════════════
# VENDORS VIEWS
# ═══════════════════════════════════════════════════════════════════

from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from django.db.models import Sum, Count, Q
from django.db import transaction
from .models import (
    Vendor,
    WalletTransaction,
    PayoutRequest,
    BulkJob,
    LedgerEntry,
    VendorPayoutMethod,
    SettlementRecord,
)
from .serializers import (
    VendorSerializer,
    WalletTransactionSerializer,
    PayoutRequestSerializer,
    BulkJobSerializer,
    LedgerEntrySerializer,
    VendorPayoutMethodSerializer,
    VendorPayoutSettingsSerializer,
    SettlementRecordSerializer,
)
from rest_framework.parsers import MultiPartParser, FormParser
from .services import process_bulk_job_async
from .permissions import IsVendorStaff, IsVendorOwnerOrManager
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from rest_framework import serializers

from .financial_service import FinancialService


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


class PublicVendorDetailView(generics.RetrieveAPIView):
    """
    GET /api/vendors/public/<id>/
    Public endpoint to view a vendor's storefront profile.
    """
    from rest_framework.permissions import AllowAny
    from .serializers import PublicVendorProfileSerializer
    
    queryset = Vendor.objects.filter(is_approved=True)
    serializer_class = PublicVendorProfileSerializer
    permission_classes = [AllowAny]


class VendorDashboardView(generics.RetrieveUpdateAPIView):
    serializer_class = VendorSerializer
    permission_classes = [IsVendorOwnerOrManager]

    def get_object(self):
        return self.request.vendor


class VendorStatsView(APIView):
    """
    GET /api/vendors/stats/
    Returns business stats for the vendor dashboard.
    """
    permission_classes = [IsVendorStaff]

    def get(self, request):
        vendor = request.vendor
        from orders.models import SubOrder, OrderItem
        from products.models import Product, ProductVariant
        from django.db.models import F, Sum, DecimalField, ExpressionWrapper
        
        now = timezone.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        seven_days_ago = now - timedelta(days=7)
        thirty_days_ago = now - timedelta(days=30)

        # Orders metrics
        suborders = SubOrder.objects.filter(vendor=vendor)
        today_orders = suborders.filter(created_at__gte=today_start).count()
        pending_orders = suborders.filter(status='PENDING').count()
        
        # Late shipments (status is pending/paid/packed and current time > ship_by_date)
        late_shipments_count = suborders.filter(
            status__in=['PENDING', 'PAID', 'PACKED'],
            ship_by_date__lt=now
        ).count()

        # Revenue
        revenue_expr = ExpressionWrapper(F('unit_price') * F('quantity'), output_field=DecimalField())
        
        revenue_7d = OrderItem.objects.filter(
            sub_order__vendor=vendor,
            sub_order__created_at__gte=seven_days_ago,
            sub_order__status__in=['DELIVERED', 'SHIPPED', 'PACKED', 'PAID']
        ).aggregate(total=Sum(revenue_expr))['total'] or Decimal('0.00')

        revenue_30d = OrderItem.objects.filter(
            sub_order__vendor=vendor,
            sub_order__created_at__gte=thirty_days_ago,
            sub_order__status__in=['DELIVERED', 'SHIPPED', 'PACKED', 'PAID']
        ).aggregate(total=Sum(revenue_expr))['total'] or Decimal('0.00')

        # Low stock
        low_stock_variants = ProductVariant.objects.filter(product__vendor=vendor).annotate(
            avail=F('stock_on_hand') - F('reserved_stock')
        ).filter(avail__lte=F('low_stock_threshold')).count()
        
        low_stock_products = Product.objects.filter(
            vendor=vendor, 
            variants__isnull=True, 
            stock_quantity__lte=5
        ).count()
        
        low_stock_count = low_stock_variants + low_stock_products

        # SLAs (Cancellation Rate & Fulfillment Rate 30d)
        orders_30d = suborders.filter(created_at__gte=thirty_days_ago)
        total_30d = orders_30d.count()
        canceled_30d = orders_30d.filter(status='CANCELED').count()
        fulfilled_30d = orders_30d.filter(status__in=['SHIPPED', 'DELIVERED']).count()

        cancellation_rate_30d = (canceled_30d / total_30d * 100) if total_30d > 0 else 0
        fulfillment_rate_30d = (fulfilled_30d / total_30d * 100) if total_30d > 0 else 0

        return Response({
            'today_orders': today_orders,
            'pending_orders': pending_orders,
            'revenue_7d': float(revenue_7d),
            'revenue_30d': float(revenue_30d),
            'low_stock_count': low_stock_count,
            'late_shipments_count': late_shipments_count,
            'cancellation_rate_30d': round(cancellation_rate_30d, 2),
            'fulfillment_rate_30d': round(fulfillment_rate_30d, 2),
            'wallet_balance': float(vendor.balance),
            'wallet_pending': float(vendor.pending_balance),
            'wallet_available': float(vendor.available_balance),
            'wallet_held': float(vendor.held_balance),
            'total_orders': suborders.count(),
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

class LedgerEntryListView(generics.ListAPIView):
    """
    GET /api/vendors/ledger/
    Returns ledger entries (ledger-first source of truth).
    """
    serializer_class = LedgerEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return LedgerEntry.objects.filter(vendor=vendor).order_by('-created_at')
        except AttributeError:
            return LedgerEntry.objects.none()


class VendorWalletSummaryView(APIView):
    """
    GET /api/vendors/wallet/summary/
    Convenience endpoint for the mobile wallet screen.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            vendor = request.user.vendor_profile
        except AttributeError:
            return Response({"error": "You are not a vendor."}, status=status.HTTP_403_FORBIDDEN)

        recent_entries = LedgerEntry.objects.filter(vendor=vendor).order_by('-created_at')[:50]
        payout_methods = VendorPayoutMethod.objects.filter(vendor=vendor).order_by('-is_verified', '-updated_at')
        recent_payouts = PayoutRequest.objects.filter(vendor=vendor).order_by('-requested_at')[:20]

        return Response({
            'balances': {
                'pending': float(vendor.pending_balance),
                'available': float(vendor.available_balance),
                'held': float(vendor.held_balance),
                'debt': float(vendor.debt_balance),
                'total': float(vendor.balance),
                'lifetime_earned': float(vendor.total_earned_lifetime),
                'lifetime_withdrawn': float(vendor.total_withdrawn_lifetime),
                'min_withdrawal': float(FinancialService.fee_config.min_withdrawal_amount),
            },
            'auto_payout': {
                'is_enabled': vendor.is_auto_payout_enabled,
                'schedule': vendor.auto_payout_schedule,
                'threshold': float(vendor.auto_payout_threshold),
                'preferred_method_id': vendor.preferred_payout_method_id,
                'last_payout_at': vendor.last_payout_at.isoformat() if vendor.last_payout_at else None,
            },
            'entries': LedgerEntrySerializer(recent_entries, many=True).data,
            'payout_methods': VendorPayoutMethodSerializer(payout_methods, many=True).data,
            'payout_requests': PayoutRequestSerializer(recent_payouts, many=True).data,
        })


class VendorPayoutMethodListCreateView(generics.ListCreateAPIView):
    serializer_class = VendorPayoutMethodSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return VendorPayoutMethod.objects.none()
        return VendorPayoutMethod.objects.filter(vendor=vendor).order_by('-is_verified', '-updated_at')

    def perform_create(self, serializer):
        vendor = self.request.user.vendor_profile
        method = serializer.save(vendor=vendor)
        # Auto-verify on creation if valid details provided
        from .disbursal_service import VendorDisbursalService
        VendorDisbursalService.verify_payout_method(method)


class VendorPayoutMethodVerifyView(APIView):
    """
    POST /api/vendors/payout-methods/<id>/verify/
    Verifies vendor's payout method (bKash/Nagad wallet or Bank).
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            vendor = request.user.vendor_profile
            method = VendorPayoutMethod.objects.get(id=pk, vendor=vendor)
        except (AttributeError, VendorPayoutMethod.DoesNotExist):
            return Response({'error': 'Payout method not found'}, status=status.HTTP_404_NOT_FOUND)

        from .disbursal_service import VendorDisbursalService
        is_valid = VendorDisbursalService.verify_payout_method(method)
        if is_valid:
            return Response({
                'status': 'verified',
                'message': f'{method.method} account verified successfully.',
                'method': VendorPayoutMethodSerializer(method).data,
            })
        else:
            return Response({
                'status': 'failed',
                'error': method.verification_notes or 'Account verification failed. Please check account details.',
            }, status=status.HTTP_400_BAD_REQUEST)


class VendorPayoutSettingsView(APIView):
    """
    GET /api/vendors/payout-settings/
    POST /api/vendors/payout-settings/
    Manages auto-payout schedule (Weekly, Bi-weekly, Monthly) and threshold.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        try:
            vendor = request.user.vendor_profile
        except AttributeError:
            return Response({'error': 'Not a vendor'}, status=status.HTTP_403_FORBIDDEN)
        serializer = VendorPayoutSettingsSerializer(vendor)
        return Response(serializer.data)

    def post(self, request, *args, **kwargs):
        try:
            vendor = request.user.vendor_profile
        except AttributeError:
            return Response({'error': 'Not a vendor'}, status=status.HTTP_403_FORBIDDEN)

        serializer = VendorPayoutSettingsSerializer(vendor, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class VendorSettlementListView(generics.ListAPIView):
    serializer_class = SettlementRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return SettlementRecord.objects.none()
        return SettlementRecord.objects.filter(vendor=vendor).order_by('-created_at')


class PayoutRequestListCreateView(generics.ListCreateAPIView):
    serializer_class = PayoutRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return PayoutRequest.objects.filter(vendor=vendor).order_by('-requested_at')
        except AttributeError:
            return PayoutRequest.objects.none()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        output_serializer = self.get_serializer(serializer.instance)
        headers = self.get_success_headers(output_serializer.data)
        return Response(output_serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        vendor = self.request.user.vendor_profile
        amount = serializer.validated_data['amount']

        payout_method_id = self.request.data.get('payout_method') or self.request.data.get('payout_method_id')
        payout_method = None
        if payout_method_id:
            try:
                payout_method = VendorPayoutMethod.objects.get(id=payout_method_id, vendor=vendor)
            except VendorPayoutMethod.DoesNotExist:
                pass

        channel = ''
        if payout_method:
            channel = payout_method.method
            if not serializer.validated_data.get('bank_details'):
                serializer.validated_data['bank_details'] = f"{payout_method.method} ({payout_method.label or 'Default'}): {payout_method.details}"

        with transaction.atomic():
            payout = serializer.save(
                vendor=vendor,
                payout_method=payout_method,
                disbursal_channel=channel or 'BANK',
            )
            try:
                FinancialService.request_payout_hold(vendor, Decimal(str(amount)), payout)
            except ValueError as e:
                raise serializers.ValidationError(str(e))

            # Auto-disburse if requested by client or if auto-disburse flag is passed
            raw_auto = self.request.data.get('auto_disburse')
            auto_disburse = raw_auto is True or str(raw_auto).strip().lower() in ('true', '1')
            if auto_disburse:
                from .disbursal_service import VendorDisbursalService
                VendorDisbursalService.disburse_payout(payout)
                payout.refresh_from_db()
                serializer.instance = payout

            # Admin inbox notification: PAYOUT_REQUESTED
            def _notify_admins() -> None:
                try:
                    from django.contrib.auth import get_user_model
                    from notifications.models import Notification
                    from notifications.services import NotificationService

                    User = get_user_model()
                    admins = User.objects.filter(type=User.Types.ADMIN)
                    for admin_user in admins:
                        NotificationService.create(
                            user=admin_user,
                            title='Payout requested',
                            body=f'Payout request #{payout.id} from {vendor.store_name} for ৳{payout.amount}.',
                            event_type=Notification.Type.PAYOUT_REQUESTED,
                            category=Notification.Category.TRANSACTIONAL,
                            deeplink=f'app://admin/payouts/{payout.id}',
                            data={'payout_id': str(payout.id), 'vendor_id': str(vendor.id)},
                            inbox_visible=True,
                            push_enabled=False,
                        )
                except Exception:
                    pass

            transaction.on_commit(_notify_admins)


class VendorPayoutDisburseView(APIView):
    """
    POST /api/vendors/payouts/<id>/disburse/
    Disburses an approved or requested payout via simulated bKash/Nagad/Bank gateway.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            vendor = request.user.vendor_profile
            payout = PayoutRequest.objects.get(id=pk, vendor=vendor)
        except (AttributeError, PayoutRequest.DoesNotExist):
            return Response({'error': 'Payout request not found'}, status=status.HTTP_404_NOT_FOUND)

        from .disbursal_service import VendorDisbursalService
        res = VendorDisbursalService.disburse_payout(payout)
        if res.get('success'):
            return Response(res)
        else:
            return Response(res, status=status.HTTP_400_BAD_REQUEST)

# ═══════════════════════════════════════════════════════════════════
# BULK OPERATIONS
# ═══════════════════════════════════════════════════════════════════
from .tasks import process_bulk_job_task

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
        # Trigger async processing via celery
        process_bulk_job_task.delay(job.id)

class BulkJobDetailView(generics.RetrieveAPIView):
    serializer_class = BulkJobSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
            return BulkJob.objects.filter(vendor=vendor)
        except AttributeError:
            return BulkJob.objects.none()
