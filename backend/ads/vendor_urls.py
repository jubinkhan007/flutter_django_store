from django.urls import path
from .views import (
    VendorAdCampaignListCreateView,
    VendorAdCampaignDetailView,
    VendorAdStatsView,
    VendorAdTopupView,
)

urlpatterns = [
    path('campaigns/', VendorAdCampaignListCreateView.as_view(), name='vendor_ad_campaigns'),
    path('campaigns/<int:pk>/', VendorAdCampaignDetailView.as_view(), name='vendor_ad_campaign_detail'),
    path('stats/', VendorAdStatsView.as_view(), name='vendor_ad_stats'),
    path('topup/', VendorAdTopupView.as_view(), name='vendor_ad_topup'),
]
