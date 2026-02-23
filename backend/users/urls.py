from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import UserRegistrationView, CustomTokenObtainPairView

urlpatterns = [
    path('auth/register/', UserRegistrationView.as_view(), name='register'),
    # Back-compat alias (some clients post to /api/register/)
    path('register/', UserRegistrationView.as_view(), name='register_legacy'),
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    # Back-compat alias (some clients post to /api/login/)
    path('login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair_legacy'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]
