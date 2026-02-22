from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView

# ✅ CORRECT: Import serializers from serializers.py, not define them here
from .serializers import UserRegistrationSerializer, CustomTokenObtainPairSerializer


# ─── Login View ─────────────────────────────────────────────────────
# WHAT: This view handles POST requests to /api/auth/login/
# WHY:  We extend TokenObtainPairView to use OUR custom serializer
#       (which embeds user type & email in the token).
# HOW:  We simply tell it: "use CustomTokenObtainPairSerializer instead of the default one"
class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer


# ─── Registration View ─────────────────────────────────────────────
# WHAT: This view handles POST requests to /api/auth/register/
# WHY:  We need an endpoint where new users can create an account.
# HOW:  CreateAPIView is a DRF shortcut that automatically:
#       1. Accepts POST data (JSON from Flutter)
#       2. Passes it to the serializer for validation
#       3. Calls serializer.create() to save to DB
#       4. Returns the created object as JSON
class UserRegistrationView(generics.CreateAPIView):
    serializer_class = UserRegistrationSerializer
    permission_classes = [AllowAny]  # Anyone can register (no token needed)

