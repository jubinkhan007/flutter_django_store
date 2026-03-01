from __future__ import annotations

from rest_framework import serializers

from .models import DeviceToken, Notification, NotificationPreference


class DeviceTokenRegisterSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)
    platform = serializers.ChoiceField(choices=DeviceToken.Platform.choices)
    device_id = serializers.CharField(max_length=100, required=False, allow_blank=True)
    app_version = serializers.CharField(max_length=50, required=False, allow_blank=True)


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = ['order_updates', 'payout_updates', 'promotions']


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            'id',
            'title',
            'body',
            'type',
            'category',
            'data',
            'deeplink',
            'is_read',
            'read_at',
            'delivery_status',
            'created_at',
        ]

