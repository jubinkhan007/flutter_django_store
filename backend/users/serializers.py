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
        token = super().get_token(user)
        token['type'] = user.type
        token['email'] = user.email
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        # Include user info in the response body so Flutter can use it immediately
        data['user'] = {
            'id': self.user.id,
            'email': self.user.email,
            'username': self.user.username,
            'type': self.user.type,
            'personalization_enabled': self.user.personalization_enabled,
        }
        return data

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

from .models import User, Address

class UserPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['personalization_enabled']

class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = ['id', 'user', 'label', 'phone_number', 'address_line', 'area', 'city', 'is_default', 'created_at', 'updated_at']
        read_only_fields = ['user', 'created_at', 'updated_at']

    def validate(self, attrs):
        # Additional validation if needed
        return attrs
