from __future__ import annotations

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Conversation, ChatMessage
from .serializers import (
    ChatMessageSerializer,
    ConversationDetailSerializer,
    ConversationListSerializer,
    SendMessageSerializer,
    StartConversationSerializer,
)
from notifications.services import NotificationService
from products.models import Product
from orders.models import Order
from vendors.models import Vendor


def _get_user_conversations(user):
    """
    Returns queryset of conversations visible to the user.
    If the user has an approved vendor profile, checks for vendor conversations,
    or falls back to customer conversations.
    """
    if hasattr(user, 'vendor_profile'):
        return Conversation.objects.filter(vendor=user.vendor_profile)
    return Conversation.objects.filter(customer=user)


class ConversationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ConversationListSerializer

    def get_queryset(self):
        return _get_user_conversations(self.request.user).select_related(
            'vendor', 'customer', 'product', 'order'
        ).order_by('-last_message_at')


class StartConversationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @transaction.atomic
    def post(self, request, *args, **kwargs):
        serializer = StartConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        vendor_id = serializer.validated_data['vendor_id']
        product_id = serializer.validated_data.get('product_id')
        order_id = serializer.validated_data.get('order_id')
        initial_message = serializer.validated_data.get('message', '').strip()

        vendor = Vendor.objects.get(id=vendor_id)
        customer = request.user

        # A vendor cannot chat with their own store
        if hasattr(customer, 'vendor_profile') and customer.vendor_profile == vendor:
            return Response(
                {'detail': 'You cannot initiate a chat with your own store.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        conversation, created = Conversation.objects.get_or_create(
            customer=customer,
            vendor=vendor,
        )

        update_fields = []
        if product_id:
            conversation.product_id = product_id
            update_fields.append('product')
        if order_id:
            conversation.order_id = order_id
            update_fields.append('order')

        if initial_message:
            msg = ChatMessage.objects.create(
                conversation=conversation,
                sender=customer,
                sender_type=ChatMessage.SenderType.CUSTOMER,
                message_type=ChatMessage.MessageType.TEXT,
                text=initial_message,
            )
            conversation.last_message_at = timezone.now()
            conversation.last_message_preview = initial_message[:100]
            conversation.vendor_unread_count += 1
            update_fields.extend(['last_message_at', 'last_message_preview', 'vendor_unread_count'])

            # Notify vendor
            try:
                NotificationService.create(
                    user=vendor.user,
                    title=f"New message from {customer.get_full_name() or customer.username}",
                    body=initial_message[:120],
                    event_type='CHAT_MESSAGE',
                    category='CHAT',
                    deeplink=f"/chat/{conversation.id}",
                    data={'conversation_id': conversation.id, 'sender_id': customer.id},
                )
            except Exception:
                pass

        if update_fields:
            conversation.save(update_fields=list(set(update_fields)))

        detail_serializer = ConversationDetailSerializer(
            conversation, context={'request': request}
        )
        return Response(detail_serializer.data, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)


class ConversationDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk, *args, **kwargs):
        try:
            conversation = Conversation.objects.select_related(
                'vendor', 'customer', 'product', 'order'
            ).get(pk=pk)
        except Conversation.DoesNotExist:
            return Response({'detail': 'Conversation not found.'}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        is_vendor = hasattr(user, 'vendor_profile') and user.vendor_profile == conversation.vendor
        is_customer = conversation.customer == user

        if not (is_vendor or is_customer or user.is_staff):
            return Response({'detail': 'Access denied.'}, status=status.HTTP_403_FORBIDDEN)

        # Mark unread messages as read
        conversation.mark_as_read_for(user)

        messages_qs = conversation.messages.select_related('sender').all()
        after_id = request.query_params.get('after_id')
        if after_id:
            try:
                messages_qs = messages_qs.filter(id__gt=int(after_id))
            except ValueError:
                pass

        # Serialize conversation
        conv_data = ConversationListSerializer(conversation, context={'request': request}).data
        messages_data = ChatMessageSerializer(messages_qs, many=True, context={'request': request}).data
        conv_data['messages'] = messages_data

        return Response(conv_data)


class SendMessageView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    @transaction.atomic
    def post(self, request, pk, *args, **kwargs):
        try:
            conversation = Conversation.objects.select_related('vendor', 'customer').get(pk=pk)
        except Conversation.DoesNotExist:
            return Response({'detail': 'Conversation not found.'}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        is_vendor = hasattr(user, 'vendor_profile') and user.vendor_profile == conversation.vendor
        is_customer = conversation.customer == user

        if not (is_vendor or is_customer or user.is_staff):
            return Response({'detail': 'Access denied.'}, status=status.HTTP_403_FORBIDDEN)

        serializer = SendMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        sender_type = ChatMessage.SenderType.VENDOR if is_vendor else ChatMessage.SenderType.CUSTOMER
        text = serializer.validated_data.get('text', '').strip()
        image = serializer.validated_data.get('image')
        message_type = serializer.validated_data.get('message_type')

        if not message_type:
            message_type = ChatMessage.MessageType.IMAGE if image else ChatMessage.MessageType.TEXT

        msg = ChatMessage.objects.create(
            conversation=conversation,
            sender=user,
            sender_type=sender_type,
            message_type=message_type,
            text=text,
            image=image,
        )

        preview = text[:100] if text else "Sent an attachment"
        conversation.last_message_at = timezone.now()
        conversation.last_message_preview = preview

        if is_vendor:
            conversation.customer_unread_count += 1
            recipient = conversation.customer
            sender_name = conversation.vendor.store_name
        else:
            conversation.vendor_unread_count += 1
            recipient = conversation.vendor.user
            sender_name = user.get_full_name() or user.username

        conversation.save(update_fields=[
            'last_message_at',
            'last_message_preview',
            'customer_unread_count' if is_vendor else 'vendor_unread_count',
        ])

        # Push / In-app notification to recipient
        try:
            NotificationService.create(
                user=recipient,
                title=f"New message from {sender_name}",
                body=preview,
                event_type='CHAT_MESSAGE',
                category='CHAT',
                deeplink=f"/chat/{conversation.id}",
                data={'conversation_id': conversation.id, 'sender_id': user.id},
            )
        except Exception:
            pass

        return Response(
            ChatMessageSerializer(msg, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )


class MarkConversationReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            conversation = Conversation.objects.get(pk=pk)
        except Conversation.DoesNotExist:
            return Response({'detail': 'Conversation not found.'}, status=status.HTTP_404_NOT_FOUND)

        user = request.user
        is_vendor = hasattr(user, 'vendor_profile') and user.vendor_profile == conversation.vendor
        is_customer = conversation.customer == user

        if not (is_vendor or is_customer or user.is_staff):
            return Response({'detail': 'Access denied.'}, status=status.HTTP_403_FORBIDDEN)

        conversation.mark_as_read_for(user)
        return Response({'status': 'ok'})


class UnreadCountView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        if hasattr(user, 'vendor_profile'):
            total = Conversation.objects.filter(vendor=user.vendor_profile).aggregate(
                total=Sum('vendor_unread_count')
            )['total'] or 0
        else:
            total = Conversation.objects.filter(customer=user).aggregate(
                total=Sum('customer_unread_count')
            )['total'] or 0

        return Response({'unread_count': total})
