from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    UserRegistrationView, 
    CustomTokenObtainPairView,
    AddressListCreateView,
    AddressDetailView
)

urlpatterns = [
    path('auth/register/', UserRegistrationView.as_view(), name='register'),
    path('register/', UserRegistrationView.as_view(), name='register_legacy'),
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair_legacy'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/addresses/', AddressListCreateView.as_view(), name='address_list_create'),
    path('auth/addresses/<int:pk>/', AddressDetailView.as_view(), name='address_detail'),
    path('addresses/', AddressListCreateView.as_view(), name='address_list_create_legacy'),
    path('addresses/<int:pk>/', AddressDetailView.as_view(), name='address_detail_legacy'),
]
