from django.urls import path
from .views import AdRecordImpressionView, AdRecordClickView

urlpatterns = [
    path('impressions/', AdRecordImpressionView.as_view(), name='ad_impression'),
    path('clicks/', AdRecordClickView.as_view(), name='ad_click'),
]
