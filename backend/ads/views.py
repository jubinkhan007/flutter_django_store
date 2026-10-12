from decimal import Decimal
from django.db import transaction, models
from django.utils import timezone
from rest_framework import generics, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response

from .models import AdCampaign, AdImpression, AdClick
from .services import AdBillingService, AdAuctionService
from .serializers import (
    AdCampaignSerializer,
    AdCampaignCreateSerializer,
    AdCampaignUpdateSerializer,
    AdTopupSerializer,
    AdImpressionSerializer,
    AdClickSerializer,
)
from vendors.permissions import IsVendorOwnerOrManager
from vendors.models import LedgerEntry

# ═══════════════════════════════════════════════════════════════════
# VENDOR AD VIEWS (Authenticated Vendor Staff/Owners)
# ═══════════════════════════════════════════════════════════════════

class VendorAdCampaignListCreateView(generics.ListCreateAPIView):
    """
    GET /api/vendors/ads/campaigns/
    POST /api/vendors/ads/campaigns/
    """
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return AdCampaign.objects.filter(vendor=self.request.vendor).select_related('product').order_by('-created_at')

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return AdCampaignCreateSerializer
        return AdCampaignSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        campaign = serializer.save()
        return Response(AdCampaignSerializer(campaign).data, status=status.HTTP_201_CREATED)


class VendorAdCampaignDetailView(generics.RetrieveUpdateAPIView):
    """
    GET /api/vendors/ads/campaigns/<id>/
    PATCH /api/vendors/ads/campaigns/<id>/
    """
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return AdCampaign.objects.filter(vendor=self.request.vendor).select_related('product')

    def get_serializer_class(self):
        if self.request.method in ['PATCH', 'PUT']:
            return AdCampaignUpdateSerializer
        return AdCampaignSerializer

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', True)
        instance = self.get_object()
        serializer = AdCampaignUpdateSerializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(AdCampaignSerializer(instance).data)


class VendorAdStatsView(APIView):
    """
    GET /api/vendors/ads/stats/
    Returns aggregate stats across all campaigns for the logged-in vendor.
    """
    permission_classes = [IsVendorOwnerOrManager]

    def get(self, request, *args, **kwargs):
        vendor = request.vendor
        campaigns = AdCampaign.objects.filter(vendor=vendor)

        total_campaigns = campaigns.count()
        active_campaigns = campaigns.filter(status=AdCampaign.Status.ACTIVE).count()

        total_spend = campaigns.aggregate(total=models.Sum('budget_spent'))['total'] or Decimal('0.00')

        total_impressions = AdImpression.objects.filter(campaign__vendor=vendor).count()
        total_clicks = AdClick.objects.filter(campaign__vendor=vendor).count()

        avg_ctr = round((total_clicks / total_impressions) * 100.0, 2) if total_impressions > 0 else 0.0

        vendor.recache_ad_balance(save=False)

        return Response({
            'total_campaigns': total_campaigns,
            'active_campaigns': active_campaigns,
            'total_impressions': total_impressions,
            'total_clicks': total_clicks,
            'total_spend': str(total_spend),
            'avg_ctr': avg_ctr,
            'ad_balance': str(vendor.ad_balance or Decimal('0.00')),
            'available_balance': str(vendor.available_balance or Decimal('0.00')),
        })


class VendorAdTopupView(APIView):
    """
    POST /api/vendors/ads/topup/
    Transfers available store earnings into Ad Credits.
    """
    permission_classes = [IsVendorOwnerOrManager]

    def post(self, request, *args, **kwargs):
        serializer = AdTopupSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        vendor = request.vendor

        with transaction.atomic():
            # Lock vendor row
            from vendors.models import Vendor
            locked_vendor = Vendor.objects.select_for_update().get(id=vendor.id)
            if (locked_vendor.available_balance or Decimal('0.00')) < amount:
                return Response(
                    {"error": "Insufficient available earnings."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # 1. Debit from available balance
            LedgerEntry.objects.create(
                vendor=locked_vendor,
                entry_type=LedgerEntry.EntryType.AD_CREDIT_TOPUP,
                bucket=LedgerEntry.Bucket.AVAILABLE,
                direction=LedgerEntry.Direction.DEBIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.AD_CAMPAIGN,
                reference_id=locked_vendor.id,
                description="Transfer to Ad Credits",
            )

            # 2. Credit to ad credits bucket
            LedgerEntry.objects.create(
                vendor=locked_vendor,
                entry_type=LedgerEntry.EntryType.AD_CREDIT_TOPUP,
                bucket=LedgerEntry.Bucket.AD_CREDITS,
                direction=LedgerEntry.Direction.CREDIT,
                status=LedgerEntry.Status.POSTED,
                amount=amount,
                reference_type=LedgerEntry.ReferenceType.AD_CAMPAIGN,
                reference_id=locked_vendor.id,
                description="Ad Credit Top-up",
            )

            locked_vendor.available_balance = (locked_vendor.available_balance or Decimal('0.00')) - amount
            locked_vendor.save(update_fields=['available_balance'])
            locked_vendor.recache_balance(save=True)
            locked_vendor.recache_ad_balance(save=True)

        return Response({
            'message': f"Successfully transferred {amount} to Ad Credits.",
            'ad_balance': str(locked_vendor.ad_balance),
            'available_balance': str(locked_vendor.available_balance),
        }, status=status.HTTP_200_OK)


# ═══════════════════════════════════════════════════════════════════
# PUBLIC AD TRACKING VIEWS (Customer impressions and clicks)
# ═══════════════════════════════════════════════════════════════════

class AdRecordImpressionView(APIView):
    """
    POST /api/ads/impressions/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = AdImpressionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_id = request.user.id if request.user.is_authenticated else None
        success = AdBillingService.record_impression(
            campaign_id=serializer.validated_data['campaign_id'],
            user_id=user_id,
            session_id=str(serializer.validated_data['session_id']),
            source=serializer.validated_data.get('source', 'HOME')
        )

        return Response({'recorded': success}, status=status.HTTP_200_OK)


class AdRecordClickView(APIView):
    """
    POST /api/ads/clicks/
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = AdClickSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_id = request.user.id if request.user.is_authenticated else None
        success = AdBillingService.record_click(
            campaign_id=serializer.validated_data['campaign_id'],
            user_id=user_id,
            session_id=str(serializer.validated_data['session_id']),
            click_id=str(serializer.validated_data['click_id'])
        )

        return Response({'recorded': success}, status=status.HTTP_200_OK)
