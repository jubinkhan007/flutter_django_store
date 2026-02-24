from django.urls import path

from .views import CouponAvailableView, CouponListView, CouponValidateView

urlpatterns = [
    path('', CouponListView.as_view(), name='coupon-list'),
    path('available/', CouponAvailableView.as_view(), name='coupon-available'),
    path('validate/', CouponValidateView.as_view(), name='coupon-validate'),
]
