from django.urls import path

from . import views

urlpatterns = [
    path('', views.VendorReturnListView.as_view(), name='vendor-return-list'),
    path('policies/', views.VendorReturnPolicyListCreateView.as_view(), name='vendor-return-policy-list'),
    path('policies/<int:pk>/', views.VendorReturnPolicyDetailView.as_view(), name='vendor-return-policy-detail'),
    path('<int:pk>/', views.VendorReturnDetailView.as_view(), name='vendor-return-detail'),
    path('<int:pk>/approve/', views.VendorApproveReturnView.as_view(), name='vendor-return-approve'),
    path('<int:pk>/reject/', views.VendorRejectReturnView.as_view(), name='vendor-return-reject'),
    path('<int:pk>/received/', views.VendorMarkReceivedView.as_view(), name='vendor-return-received'),
    path('<int:pk>/refund/', views.VendorInitiateRefundView.as_view(), name='vendor-return-refund'),
    path('<int:pk>/refund/complete/', views.VendorCompleteRefundView.as_view(), name='vendor-return-refund-complete'),
]
