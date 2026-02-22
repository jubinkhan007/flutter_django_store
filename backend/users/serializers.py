from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model

User = get_user_model()


# ─── Token Serializer ───────────────────────────────────────────────
# WHY: The default login response only returns tokens: {"access": "...", "refresh": "..."}
# We want to also embed the user's type and email INSIDE the token itself.
# This way, the Flutter app can decode the token and know: "This is a VENDOR" or "This is a CUSTOMER"
# without making an extra API call.
#
# HOW: We override get_token() to add extra "claims" (key-value pairs baked into the token).
class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        # super().get_token(user) gives us the default token with just user ID
        token = super().get_token(user)

        # Now we add our custom data to it
        token['type'] = user.type    # "CUSTOMER", "VENDOR", or "ADMIN"
        token['email'] = user.email  # e.g., "test@example.com"

        return token

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('id', 'email', 'username', 'password', 'type')
    
    def create(self, validated_data):
        # We must use create_user to hash the password correctly
        user = User.objects.create_user(
            email=validated_data['email'],
            username=validated_data['username'],
            password=validated_data['password'],
            type=validated_data.get('type', User.Types.CUSTOMER)
        )
        return user
