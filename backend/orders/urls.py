from django.urls import path
from . import views

urlpatterns = [
    # Customer endpoints
    path('', views.CustomerOrderListView.as_view(), name='customer-order-list'),
    path('place/', views.CustomerPlaceOrderView.as_view(), name='customer-place-order'),
    path('<int:pk>/', views.CustomerOrderDetailView.as_view(), name='customer-order-detail'),
    path('<int:pk>/cancel/', views.CustomerOrderCancelView.as_view(), name='customer-order-cancel'),

    # SSLCommerz Payment endpoints
    path('<int:pk>/pay/', views.SSLCommerzPaymentInitiateView.as_view(), name='payment-initiate'),
    path('payment/success/', views.SSLCommerzSuccessView.as_view(), name='payment-success'),
    path('payment/fail/', views.SSLCommerzFailView.as_view(), name='payment-fail'),
    path('payment/cancel/', views.SSLCommerzCancelView.as_view(), name='payment-cancel'),
]
