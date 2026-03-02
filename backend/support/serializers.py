from __future__ import annotations

from rest_framework import serializers

from .models import Ticket, TicketAttachment, TicketMessage


class TicketMessageAttachmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = TicketAttachment
        fields = ['id', 'file', 'file_type', 'size', 'storage_key', 'uploaded_at']


class TicketMessageSerializer(serializers.ModelSerializer):
    attachments = TicketMessageAttachmentSerializer(many=True, read_only=True)
    sender_id = serializers.IntegerField(source='sender.id', read_only=True)

    class Meta:
        model = TicketMessage
        fields = [
            'id',
            'ticket',
            'sender_id',
            'kind',
            'text',
            'is_internal_note',
            'attachments',
            'created_at',
        ]
        read_only_fields = ['id', 'ticket', 'sender_id', 'attachments', 'created_at']


class TicketListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ticket
        fields = [
            'id',
            'ticket_number',
            'subject',
            'category',
            'status',
            'last_activity_at',
            'created_at',
            'order_id',
            'sub_order_id',
            'return_request_id',
            'vendor_id',
            'assigned_to_id',
            'is_overdue_first_response',
            'is_overdue_resolution',
        ]


class TicketDetailSerializer(serializers.ModelSerializer):
    messages = TicketMessageSerializer(many=True, read_only=True)

    class Meta:
        model = Ticket
        fields = [
            'id',
            'ticket_number',
            'subject',
            'category',
            'status',
            'customer_id',
            'vendor_id',
            'order_id',
            'sub_order_id',
            'return_request_id',
            'assigned_to_id',
            'first_response_at',
            'resolved_at',
            'closed_at',
            'last_activity_at',
            'is_overdue_first_response',
            'is_overdue_resolution',
            'context_snapshot',
            'messages',
            'created_at',
            'updated_at',
        ]
        read_only_fields = fields

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        user_type = getattr(getattr(request, 'user', None), 'type', None)
        if user_type != 'ADMIN':
            data['messages'] = [m for m in (data.get('messages') or []) if not m.get('is_internal_note')]
        return data


class TicketCreateSerializer(serializers.Serializer):
    category = serializers.ChoiceField(choices=Ticket.Category.choices, required=False)
    subject = serializers.CharField(max_length=255, required=False, allow_blank=True)
    order_id = serializers.IntegerField(required=False)
    sub_order_id = serializers.IntegerField(required=False)
    return_request_id = serializers.IntegerField(required=False)
    message = serializers.CharField(required=True, allow_blank=False)


class TicketAssignSerializer(serializers.Serializer):
    assigned_to_id = serializers.IntegerField(required=True)


class TicketStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Ticket.Status.choices)


class TicketMessageCreateSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=TicketMessage.Kind.choices, required=False)
    text = serializers.CharField(required=False, allow_blank=True)
    is_internal_note = serializers.BooleanField(required=False, default=False)
