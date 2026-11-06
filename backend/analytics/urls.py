from django.urls import path

from .views import MarketplaceSummaryAnalyticsView, UserEventLogView

urlpatterns = [
    path('events/', UserEventLogView.as_view(), name='analytics_events'),
    path('marketplace/summary/', MarketplaceSummaryAnalyticsView.as_view(), name='analytics_marketplace_summary'),
]


