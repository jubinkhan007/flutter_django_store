from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from orders.models import Order, SubOrder
from returns.models import ReturnRequest

from notifications.models import Notification
from notifications.services import NotificationService

from .models import Ticket, TicketAttachment, TicketMessage
from .permissions import IsAdminSupport
from .serializers import (
    TicketAssignSerializer,
    TicketCreateSerializer,
    TicketDetailSerializer,
    TicketListSerializer,
    TicketMessageCreateSerializer,
    TicketMessageSerializer,
    TicketStatusSerializer,
)


def _ticket_queryset_for_user(user):
    if getattr(user, 'type', None) == 'ADMIN':
        return Ticket.objects.all()

    if getattr(user, 'type', None) == 'VENDOR':
        try:
            vendor = user.vendor_profile
        except AttributeError:
            return Ticket.objects.none()
        return Ticket.objects.filter(vendor=vendor)

    return Ticket.objects.filter(customer=user)


class TicketListCreateView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get(self, request, *args, **kwargs):
        qs = _ticket_queryset_for_user(request.user).order_by('-last_activity_at')
        status_filter = request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response(TicketListSerializer(qs, many=True).data)

    def post(self, request, *args, **kwargs):
        serializer = TicketCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        if getattr(user, 'type', None) not in ('CUSTOMER', 'VENDOR'):
            return Response({'error': 'Unsupported user type.'}, status=status.HTTP_400_BAD_REQUEST)

        subject = serializer.validated_data.get('subject', '').strip()
        category = serializer.validated_data.get('category') or Ticket.Category.OTHER
        order_id = serializer.validated_data.get('order_id')
        sub_order_id = serializer.validated_data.get('sub_order_id')
        return_request_id = serializer.validated_data.get('return_request_id')
        message_text = serializer.validated_data['message'].strip()
        files = request.FILES.getlist('images')

        order = None
        sub_order = None
        rr = None
        vendor = None

        if return_request_id:
            rr = ReturnRequest.objects.select_related('order', 'vendor', 'customer').get(id=return_request_id)
            order = rr.order
            vendor = rr.vendor

        if sub_order_id:
            sub_order = SubOrder.objects.select_related('order', 'vendor', 'order__customer').get(id=sub_order_id)
            order = sub_order.order
            vendor = sub_order.vendor

        if order_id and not order:
            order = Order.objects.select_related('customer').get(id=order_id)

        # Access control for vendor customers
        if getattr(user, 'type', None) == 'CUSTOMER':
            if order and order.customer_id != user.id:
                return Response({'error': 'Order not found.'}, status=status.HTTP_404_NOT_FOUND)
            if rr and rr.customer_id != user.id:
                return Response({'error': 'Return not found.'}, status=status.HTTP_404_NOT_FOUND)
        elif getattr(user, 'type', None) == 'VENDOR':
            try:
                my_vendor = user.vendor_profile
            except AttributeError:
                return Response({'error': 'Not a vendor.'}, status=status.HTTP_403_FORBIDDEN)
            if vendor and vendor.id != my_vendor.id:
                return Response({'error': 'Not allowed.'}, status=status.HTTP_403_FORBIDDEN)
            vendor = my_vendor

        with transaction.atomic():
            ticket = Ticket.objects.create(
                subject=subject or 'Support request',
                category=category,
                order=order,
                sub_order=sub_order,
                return_request=rr,
                vendor=vendor,
                customer=order.customer if order else (rr.customer if rr else user),
                status=Ticket.Status.OPEN,
                last_activity_at=timezone.now(),
            )
            msg = TicketMessage.objects.create(
                ticket=ticket,
                sender=user,
                kind=TicketMessage.Kind.TEXT,
                text=message_text,
                is_internal_note=False,
            )
            for f in files:
                TicketAttachment.objects.create(
                    message=msg,
                    file=f,
                    file_type=getattr(f, 'content_type', '') or '',
                    size=getattr(f, 'size', 0) or 0,
                )

            def _notify() -> None:
                # Notify admins/support that a ticket was created.
                try:
                    from django.contrib.auth import get_user_model

                    User = get_user_model()
                    admins = User.objects.filter(type=User.Types.ADMIN)
                    for admin_user in admins:
                        NotificationService.create(
                            user=admin_user,
                            title='New support ticket',
                            body=f'{ticket.ticket_number} created.',
                            event_type=Notification.Type.TICKET_CREATED,
                            category=Notification.Category.TRANSACTIONAL,
                            deeplink=f'app://support/tickets/{ticket.id}',
                            data={'ticket_id': str(ticket.id)},
                            inbox_visible=True,
                            push_enabled=True,
                        )
                except Exception:
                    pass

            transaction.on_commit(_notify)

        return Response(TicketDetailSerializer(ticket).data, status=status.HTTP_201_CREATED)


class TicketDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TicketDetailSerializer

    def get_queryset(self):
        return _ticket_queryset_for_user(self.request.user)


class TicketMessageCreateView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def post(self, request, pk: int, *args, **kwargs):
        serializer = TicketMessageCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            ticket = _ticket_queryset_for_user(request.user).get(id=pk)
        except Ticket.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if ticket.status == Ticket.Status.CLOSED and getattr(request.user, 'type', None) != 'ADMIN':
            return Response({'error': 'Ticket is closed.'}, status=status.HTTP_400_BAD_REQUEST)

        is_internal = bool(serializer.validated_data.get('is_internal_note', False))
        if is_internal and getattr(request.user, 'type', None) != 'ADMIN':
            return Response({'error': 'Not allowed.'}, status=status.HTTP_403_FORBIDDEN)

        files = request.FILES.getlist('images')
        kind = serializer.validated_data.get('kind') or (TicketMessage.Kind.IMAGE if files else TicketMessage.Kind.TEXT)
        text = serializer.validated_data.get('text', '').strip()
        if not text and not files:
            return Response({'error': 'Message text or image is required.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            msg = TicketMessage.objects.create(
                ticket=ticket,
                sender=request.user,
                kind=kind,
                text=text,
                is_internal_note=is_internal,
            )
            for f in files:
                TicketAttachment.objects.create(
                    message=msg,
                    file=f,
                    file_type=getattr(f, 'content_type', '') or '',
                    size=getattr(f, 'size', 0) or 0,
                )
            Ticket.objects.filter(id=ticket.id).update(last_activity_at=timezone.now())

            # First response SLA: first message by ADMIN counts as first response.
            if getattr(request.user, 'type', None) == 'ADMIN' and not ticket.first_response_at:
                ticket.first_response_at = timezone.now()
                ticket.save(update_fields=['first_response_at', 'updated_at'])

            def _notify() -> None:
                # Reply received notification
                try:
                    actor_type = getattr(request.user, 'type', None)

                    if actor_type == 'ADMIN':
                        # Notify customer (and vendor if present)
                        NotificationService.create(
                            user=ticket.customer,
                            title='Support reply',
                            body=f'New reply on {ticket.ticket_number}.',
                            event_type=Notification.Type.TICKET_REPLY_RECEIVED,
                            category=Notification.Category.TRANSACTIONAL,
                            deeplink=f'app://support/tickets/{ticket.id}',
                            data={'ticket_id': str(ticket.id)},
                            inbox_visible=True,
                            push_enabled=True,
                        )
                        if ticket.vendor_id:
                            NotificationService.create(
                                user=ticket.vendor.user,
                                title='Support reply',
                                body=f'New reply on {ticket.ticket_number}.',
                                event_type=Notification.Type.TICKET_REPLY_RECEIVED,
                                category=Notification.Category.TRANSACTIONAL,
                                deeplink=f'app://support/tickets/{ticket.id}',
                                data={'ticket_id': str(ticket.id)},
                                inbox_visible=True,
                                push_enabled=True,
                            )
                    else:
                        # Notify assigned agent if any; otherwise notify all admins.
                        if ticket.assigned_to_id:
                            NotificationService.create(
                                user=ticket.assigned_to,
                                title='Ticket reply received',
                                body=f'New message on {ticket.ticket_number}.',
                                event_type=Notification.Type.TICKET_REPLY_RECEIVED,
                                category=Notification.Category.TRANSACTIONAL,
                                deeplink=f'app://support/tickets/{ticket.id}',
                                data={'ticket_id': str(ticket.id)},
                                inbox_visible=True,
                                push_enabled=True,
                            )
                        else:
                            from django.contrib.auth import get_user_model

                            User = get_user_model()
                            admins = User.objects.filter(type=User.Types.ADMIN)
                            for admin_user in admins:
                                NotificationService.create(
                                    user=admin_user,
                                    title='Ticket reply received',
                                    body=f'New message on {ticket.ticket_number}.',
                                    event_type=Notification.Type.TICKET_REPLY_RECEIVED,
                                    category=Notification.Category.TRANSACTIONAL,
                                    deeplink=f'app://support/tickets/{ticket.id}',
                                    data={'ticket_id': str(ticket.id)},
                                    inbox_visible=True,
                                    push_enabled=True,
                                )
                except Exception:
                    pass

            transaction.on_commit(_notify)

        return Response(TicketMessageSerializer(msg).data, status=status.HTTP_201_CREATED)


class TicketAssignView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminSupport]

    def post(self, request, pk: int, *args, **kwargs):
        serializer = TicketAssignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        assigned_to_id = serializer.validated_data['assigned_to_id']

        from django.contrib.auth import get_user_model

        User = get_user_model()
        try:
            agent = User.objects.get(id=assigned_to_id, type=User.Types.ADMIN)
        except User.DoesNotExist:
            return Response({'error': 'Agent not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            ticket = Ticket.objects.get(id=pk)
        except Ticket.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        ticket.assigned_to = agent
        ticket.save(update_fields=['assigned_to', 'updated_at'])
        return Response(TicketDetailSerializer(ticket).data)


class TicketStatusUpdateView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminSupport]

    def post(self, request, pk: int, *args, **kwargs):
        serializer = TicketStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data['status']

        try:
            ticket = Ticket.objects.get(id=pk)
        except Ticket.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        with transaction.atomic():
            ticket.status = new_status
            if new_status == Ticket.Status.RESOLVED and not ticket.resolved_at:
                ticket.resolved_at = timezone.now()
            if new_status == Ticket.Status.CLOSED and not ticket.closed_at:
                ticket.closed_at = timezone.now()
            ticket.save(update_fields=['status', 'resolved_at', 'closed_at', 'updated_at'])

            TicketMessage.objects.create(
                ticket=ticket,
                sender=request.user,
                kind=TicketMessage.Kind.SYSTEM_EVENT,
                text=f'Status changed to {new_status}.',
                is_internal_note=True,
            )

        return Response(TicketDetailSerializer(ticket).data)


class TicketCloseView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int, *args, **kwargs):
        try:
            ticket = _ticket_queryset_for_user(request.user).get(id=pk)
        except Ticket.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if ticket.status == Ticket.Status.CLOSED:
            return Response(TicketDetailSerializer(ticket).data)

        if getattr(request.user, 'type', None) != 'ADMIN' and ticket.status != Ticket.Status.RESOLVED:
            return Response({'error': 'Only RESOLVED tickets can be closed.'}, status=status.HTTP_400_BAD_REQUEST)

        ticket.status = Ticket.Status.CLOSED
        ticket.closed_at = timezone.now()
        ticket.save(update_fields=['status', 'closed_at', 'updated_at'])
        return Response(TicketDetailSerializer(ticket).data)


class TicketReopenView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int, *args, **kwargs):
        try:
            ticket = _ticket_queryset_for_user(request.user).get(id=pk)
        except Ticket.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if not ticket.can_reopen() and getattr(request.user, 'type', None) != 'ADMIN':
            return Response({'error': 'Ticket cannot be reopened.'}, status=status.HTTP_400_BAD_REQUEST)

        ticket.status = Ticket.Status.OPEN
        ticket.resolved_at = None
        ticket.closed_at = None
        ticket.save(update_fields=['status', 'resolved_at', 'closed_at', 'updated_at'])
        return Response(TicketDetailSerializer(ticket).data)
