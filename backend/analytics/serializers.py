from __future__ import annotations

import uuid

from rest_framework import serializers

from .models import UserEvent


class UserEventInSerializer(serializers.Serializer):
    event_type = serializers.ChoiceField(choices=UserEvent.EventType.choices)
    source = serializers.ChoiceField(choices=UserEvent.Source.choices)
    product_id = serializers.IntegerField(required=False, allow_null=True)
    session_id = serializers.UUIDField(required=False, allow_null=True)
    metadata = serializers.JSONField(required=False)

    def validate_session_id(self, value):
        # Allow null for authenticated users; guests must provide it in the view.
        if value is None:
            return None
        if not isinstance(value, uuid.UUID):
            raise serializers.ValidationError('Invalid session_id')
        return value


class UserEventBatchInSerializer(serializers.Serializer):
    events = serializers.ListField(child=UserEventInSerializer(), allow_empty=False)

    def validate_events(self, value):
        if len(value) > 50:
            raise serializers.ValidationError('Too many events in one request (max 50).')
        return value


class UserEventOutSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserEvent
        fields = [
            'id',
            'event_type',
            'source',
            'product_id',
            'user_id',
            'session_id',
            'metadata',
            'created_at',
        ]

