from __future__ import annotations

from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from .models import DeviceToken, Notification, NotificationPreference
from .serializers import (
    DeviceTokenRegisterSerializer,
    NotificationPreferenceSerializer,
    NotificationSerializer,
)


class DeviceTokenRegisterView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = DeviceTokenRegisterSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token = serializer.validated_data['token']
        platform = serializer.validated_data['platform']
        device_id = serializer.validated_data.get('device_id', '')
        app_version = serializer.validated_data.get('app_version', '')

        with transaction.atomic():
            obj, _ = DeviceToken.objects.update_or_create(
                token=token,
                defaults={
                    'user': request.user,
                    'platform': platform,
                    'device_id': device_id,
                    'app_version': app_version,
                    'is_active': True,
                    'last_seen_at': timezone.now(),
                },
            )

        return Response({'ok': True, 'id': obj.id})


class NotificationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        qs = Notification.objects.filter(user=self.request.user, inbox_visible=True)
        unread = self.request.query_params.get('unread')
        if unread in ('1', 'true', 'yes'):
            qs = qs.filter(is_read=False)
        return qs.order_by('-created_at')


class NotificationUnreadCountView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        count = Notification.objects.filter(
            user=request.user,
            inbox_visible=True,
            is_read=False,
        ).count()
        return Response({'unread': count})


class NotificationMarkReadView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: str, *args, **kwargs):
        try:
            notif = Notification.objects.get(id=pk, user=request.user, inbox_visible=True)
        except Notification.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        notif.mark_read()
        return Response(NotificationSerializer(notif).data)


class NotificationMarkAllReadView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        now = timezone.now()
        Notification.objects.filter(user=request.user, inbox_visible=True, is_read=False).update(
            is_read=True,
            read_at=now,
            updated_at=now,
        )
        return Response({'ok': True})


class NotificationPreferenceView(generics.RetrieveUpdateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = NotificationPreferenceSerializer

    def get_object(self):
        obj, _ = NotificationPreference.objects.get_or_create(user=self.request.user)
        return obj

