from django.urls import path

from .views import VendorCouponListCreateView, VendorCouponDetailView

urlpatterns = [
    path('', VendorCouponListCreateView.as_view(), name='vendor-coupon-list'),
    path('<int:pk>/', VendorCouponDetailView.as_view(), name='vendor-coupon-detail'),
]

