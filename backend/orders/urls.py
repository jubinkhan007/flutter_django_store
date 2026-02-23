from django.urls import path
from . import views

urlpatterns = [
    # Customer endpoints
    path('', views.CustomerOrderListView.as_view(), name='customer-order-list'),
    path('place/', views.CustomerPlaceOrderView.as_view(), name='customer-place-order'),
    path('<int:pk>/', views.CustomerOrderDetailView.as_view(), name='customer-order-detail'),
]
