from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from django.db.models import Sum, F, DecimalField, IntegerField
from django.db.models.functions import Coalesce
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

from vendors.models import Vendor, VendorProductAnalyticsDaily

class VendorProductAnalyticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Returns pre-aggregated funnel stats per product for the authenticated vendor.
        Returns array of products with funnel metrics.
        """
        try:
            vendor = request.user.vendor_profile
        except Vendor.DoesNotExist:
            return Response({"error": "User is not a vendor"}, status=status.HTTP_403_FORBIDDEN)
            
        period_days = int(request.query_params.get('days', 30))
        start_date = timezone.now().date() - timedelta(days=period_days)
        
        # Aggregate across the date range per product
        analytics = VendorProductAnalyticsDaily.objects.filter(
            vendor=vendor,
            date__gte=start_date
        ).values(
            'product_id', 
            'product__name'
        ).annotate(
            total_impressions=Coalesce(Sum('impressions'), 0, output_field=IntegerField()),
            total_clicks=Coalesce(Sum('clicks'), 0, output_field=IntegerField()),
            total_carts=Coalesce(Sum('carts'), 0, output_field=IntegerField()),
            total_purchases=Coalesce(Sum('purchases'), 0, output_field=IntegerField()),
            total_revenue=Coalesce(Sum('revenue'), Decimal('0.00'), output_field=DecimalField()),
            total_sponsored_impressions=Coalesce(Sum('sponsored_impressions'), 0, output_field=IntegerField()),
            total_sponsored_clicks=Coalesce(Sum('sponsored_clicks'), 0, output_field=IntegerField()),
        ).order_by('-total_purchases')
        
        results = []
        for item in analytics:
            impressions = item['total_impressions']
            clicks = item['total_clicks']
            purchases = item['total_purchases']
            
            ctr = round((clicks / impressions * 100), 2) if impressions > 0 else 0.0
            cvr = round((purchases / clicks * 100), 2) if clicks > 0 else 0.0
            
            results.append({
                "product_id": item['product_id'],
                "product_name": item['product__name'],
                "funnel": {
                    "impressions": impressions,
                    "clicks": clicks,
                    "carts": item['total_carts'],
                    "purchases": purchases,
                },
                "sponsored": {
                    "impressions": item['total_sponsored_impressions'],
                    "clicks": item['total_sponsored_clicks'],
                },
                "metrics": {
                    "ctr_percentage": ctr,
                    "cvr_percentage": cvr,
                    "revenue": float(item['total_revenue'])
                }
            })
            
        return Response(results)


class VendorSLAScoreView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Returns SLA Scorecard for the vendor.
        """
        try:
            vendor = request.user.vendor_profile
        except Vendor.DoesNotExist:
            return Response({"error": "User is not a vendor"}, status=status.HTTP_403_FORBIDDEN)
            
        # compute dynamic returns_rate if possible, or use 0 for now
        # A true implementation would count Returns / Delivered over 30 days
        returns_rate = 0.0 # Placeholder pending Returns module integration
        
        return Response({
            "cancellation_rate": float(vendor.cancellation_rate),
            "late_shipment_rate": float(vendor.late_shipment_rate),
            "avg_handling_time_days": float(vendor.avg_handling_time_days),
            "returns_rate": returns_rate
        })
