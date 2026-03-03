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


from rest_framework.permissions import IsAuthenticated
from .models import Address
from .serializers import AddressSerializer, UserPreferenceSerializer

class UserPreferenceView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserPreferenceSerializer

    def get_object(self):
        return self.request.user

class AddressListCreateView(generics.ListCreateAPIView):
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return self.request.user.addresses.all()

    def perform_create(self, serializer):
        # If this is the first address or marked as default, handle default logic
        is_default = serializer.validated_data.get('is_default', False)
        if is_default or not self.request.user.addresses.exists():
            # Unset other defaults
            self.request.user.addresses.update(is_default=False)
            serializer.save(user=self.request.user, is_default=True)
        else:
            serializer.save(user=self.request.user)

class AddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return self.request.user.addresses.all()

    def perform_update(self, serializer):
        is_default = serializer.validated_data.get('is_default', False)
        if is_default:
            self.request.user.addresses.exclude(pk=self.get_object().pk).update(is_default=False)
        serializer.save()

    def perform_destroy(self, instance):
        if instance.is_default:
            # If deleting the default, make another one default if it exists
            other_address = self.request.user.addresses.exclude(pk=instance.pk).first()
            if other_address:
                other_address.is_default = True
                other_address.save()
        instance.delete()
