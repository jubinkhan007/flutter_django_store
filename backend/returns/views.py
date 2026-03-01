from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from orders.models import Order, OrderItem
from vendors.models import Vendor

from .models import Refund, ReturnImage, ReturnItem, ReturnRequest
from .serializers import (
  ReturnCreateSerializer,
  ReturnRequestSerializer,
  VendorReturnPolicySerializer,
  VendorRefundCompleteSerializer,
  VendorRefundActionSerializer,
  VendorReturnActionSerializer,
)
from vendors.financial_service import FinancialService
from .services import check_return_eligibility, create_refund, process_wallet_refund
from .models import ReturnPolicy
from .sslcommerz_refund_client import SSLCommerzRefundClient
import uuid


class CustomerReturnListCreateView(generics.GenericAPIView):
    """
    GET /api/returns/
    POST /api/returns/
    """

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ReturnCreateSerializer

    def get(self, request, *args, **kwargs):
        qs = ReturnRequest.objects.filter(customer=request.user).order_by('-created_at')
        return Response(ReturnRequestSerializer(qs, many=True).data)

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order_id = serializer.validated_data['order_id']
        items_data = serializer.validated_data['items']
        request_type = serializer.validated_data['request_type']
        reason = serializer.validated_data['reason']
        reason_details = serializer.validated_data.get('reason_details', '')
        customer_note = serializer.validated_data.get('customer_note', '')
        fulfillment = serializer.validated_data.get('fulfillment', ReturnRequest.Fulfillment.PICKUP)
        refund_method_preference = serializer.validated_data.get(
            'refund_method_preference',
            ReturnRequest.RefundMethod.ORIGINAL,
        )

        try:
            order = Order.objects.get(id=order_id, customer=request.user)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found.'}, status=status.HTTP_404_NOT_FOUND)

        order_item_ids = [i['order_item_id'] for i in items_data]
        order_items = list(
            OrderItem.objects.select_related('product', 'sub_order__vendor', 'product__category')
            .filter(sub_order__order=order, id__in=order_item_ids)
        )
        if len(order_items) != len(set(order_item_ids)):
            return Response({'error': 'Some order items are invalid.'}, status=status.HTTP_400_BAD_REQUEST)

        items_by_id = {oi.id: oi for oi in order_items}

        grouped: dict[int, list[dict]] = {}
        for item in items_data:
            oi = items_by_id[item['order_item_id']]
            vendor_id = oi.sub_order.vendor_id if getattr(oi, 'sub_order_id', None) else None
            if vendor_id is None:
                return Response({'error': 'Invalid vendor for an order item.'}, status=status.HTTP_400_BAD_REQUEST)
            grouped.setdefault(vendor_id, []).append(
                {
                    'order_item': oi,
                    'quantity': item['quantity'],
                    'condition': item.get('condition', ReturnRequest.ItemCondition.UNOPENED),
                }
            )

        created_returns = []
        due_hours = getattr(settings, 'RMA_VENDOR_RESPONSE_HOURS', 48)
        vendor_due_at = timezone.now() + timedelta(hours=due_hours)

        with transaction.atomic():
            for vendor_id, vendor_items in grouped.items():
                vendor = Vendor.objects.get(id=vendor_id)
                elig = check_return_eligibility(
                    order=order,
                    vendor=vendor,
                    items=vendor_items,
                    request_type=request_type,
                )
                if not elig.ok:
                    return Response({'error': elig.error}, status=status.HTTP_400_BAD_REQUEST)

                rr = ReturnRequest.objects.create(
                    order=order,
                    customer=request.user,
                    vendor=vendor,
                    request_type=request_type,
                    reason=reason,
                    reason_details=reason_details,
                    customer_note=customer_note,
                    fulfillment=fulfillment,
                    refund_method_preference=refund_method_preference,
                    vendor_response_due_at=vendor_due_at,
                    status=ReturnRequest.Status.SUBMITTED,
                )

                for vi in vendor_items:
                    ReturnItem.objects.create(
                        return_request=rr,
                        order_item=vi['order_item'],
                        quantity=vi['quantity'],
                        condition=vi['condition'],
                    )

                created_returns.append(rr)

        return Response(
            {'returns': ReturnRequestSerializer(created_returns, many=True).data},
            status=status.HTTP_201_CREATED,
        )


class CustomerReturnDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ReturnRequestSerializer

    def get_queryset(self):
        return ReturnRequest.objects.filter(customer=self.request.user)


class CustomerReturnCancelView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            rr = ReturnRequest.objects.get(id=pk, customer=request.user)
        except ReturnRequest.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if rr.status != ReturnRequest.Status.SUBMITTED:
            return Response({'error': 'Only SUBMITTED requests can be canceled.'}, status=status.HTTP_400_BAD_REQUEST)

        rr.status = ReturnRequest.Status.CANCELED
        rr.save(update_fields=['status', 'updated_at'])
        return Response(ReturnRequestSerializer(rr).data)


class CustomerReturnImageUploadView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk, *args, **kwargs):
        try:
            rr = ReturnRequest.objects.get(id=pk, customer=request.user)
        except ReturnRequest.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        files = request.FILES.getlist('images')
        if not files:
            return Response({'error': 'No images provided.'}, status=status.HTTP_400_BAD_REQUEST)

        for f in files:
            ReturnImage.objects.create(return_request=rr, image=f, uploaded_by=request.user)

        return Response(ReturnRequestSerializer(rr).data, status=status.HTTP_201_CREATED)


class VendorReturnListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ReturnRequestSerializer

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return ReturnRequest.objects.none()
        return ReturnRequest.objects.filter(vendor=vendor).order_by('-created_at')


class VendorReturnDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ReturnRequestSerializer

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return ReturnRequest.objects.none()
        return ReturnRequest.objects.filter(vendor=vendor)


class VendorApproveReturnView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorReturnActionSerializer

    def post(self, request, pk, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            vendor = request.user.vendor_profile
            rr = ReturnRequest.objects.get(id=pk, vendor=vendor)
        except (AttributeError, ReturnRequest.DoesNotExist):
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if rr.status not in [ReturnRequest.Status.SUBMITTED, ReturnRequest.Status.ESCALATED]:
            return Response({'error': 'Return request is not awaiting approval.'}, status=status.HTTP_400_BAD_REQUEST)

        rr.vendor_note = serializer.validated_data.get('note', '')
        rr.pickup_window_start = serializer.validated_data.get('pickup_window_start')
        rr.pickup_window_end = serializer.validated_data.get('pickup_window_end')
        rr.dropoff_instructions = serializer.validated_data.get('dropoff_instructions', rr.dropoff_instructions)
        rr.approved_at = timezone.now()
        if rr.fulfillment == ReturnRequest.Fulfillment.DROPOFF:
            rr.status = ReturnRequest.Status.DROPOFF_REQUESTED
        elif rr.pickup_window_start and rr.pickup_window_end:
            rr.status = ReturnRequest.Status.PICKUP_SCHEDULED
        else:
            rr.status = ReturnRequest.Status.VENDOR_APPROVED
        rr.save()
        return Response(ReturnRequestSerializer(rr).data)


class VendorRejectReturnView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorReturnActionSerializer

    def post(self, request, pk, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            vendor = request.user.vendor_profile
            rr = ReturnRequest.objects.get(id=pk, vendor=vendor)
        except (AttributeError, ReturnRequest.DoesNotExist):
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if rr.status not in [ReturnRequest.Status.SUBMITTED, ReturnRequest.Status.ESCALATED]:
            return Response({'error': 'Return request is not awaiting decision.'}, status=status.HTTP_400_BAD_REQUEST)

        rr.status = ReturnRequest.Status.VENDOR_REJECTED
        rr.vendor_note = serializer.validated_data.get('note', '')
        rr.rejected_at = timezone.now()
        rr.save()
        return Response(ReturnRequestSerializer(rr).data)


class VendorMarkReceivedView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk, *args, **kwargs):
        try:
            vendor = request.user.vendor_profile
            rr = ReturnRequest.objects.get(id=pk, vendor=vendor)
        except (AttributeError, ReturnRequest.DoesNotExist):
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if rr.status not in [ReturnRequest.Status.VENDOR_APPROVED, ReturnRequest.Status.PICKUP_SCHEDULED, ReturnRequest.Status.DROPOFF_REQUESTED]:
            return Response({'error': 'Return must be approved before marking received.'}, status=status.HTTP_400_BAD_REQUEST)

        rr.status = ReturnRequest.Status.RECEIVED
        rr.received_at = timezone.now()
        rr.save()
        return Response(ReturnRequestSerializer(rr).data)


class VendorInitiateRefundView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorRefundActionSerializer

    def post(self, request, pk, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            vendor = request.user.vendor_profile
            rr = ReturnRequest.objects.get(id=pk, vendor=vendor)
        except (AttributeError, ReturnRequest.DoesNotExist):
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if rr.status not in [ReturnRequest.Status.RECEIVED, ReturnRequest.Status.REFUND_PENDING]:
            return Response({'error': 'Return must be received before refund.'}, status=status.HTTP_400_BAD_REQUEST)

        method = serializer.validated_data['method']
        amount = serializer.validated_data.get('amount')

        if method == ReturnRequest.RefundMethod.ORIGINAL:
            if rr.order.payment_method != Order.PaymentMethod.ONLINE:
                return Response(
                    {'error': 'Original-method refunds are only supported for ONLINE payments.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if rr.order.payment_status != Order.PaymentStatus.PAID:
                return Response(
                    {'error': 'Order must be PAID to refund to original method.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not getattr(rr.order, 'bank_tran_id', None):
                return Response(
                    {
                        'error': 'Missing SSLCommerz bank_tran_id for this order; cannot initiate original-method refund.'
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Idempotency: prevent multiple simultaneous refund initiations.
        if method == ReturnRequest.RefundMethod.ORIGINAL:
            in_flight = rr.refunds.filter(
                method=ReturnRequest.RefundMethod.ORIGINAL,
                status__in=[Refund.Status.PENDING, Refund.Status.PROCESSING],
            ).exists()
            if in_flight:
                rr.status = ReturnRequest.Status.REFUND_PENDING
                rr.save(update_fields=['status', 'updated_at'])
                return Response(
                    ReturnRequestSerializer(rr).data,
                    status=status.HTTP_202_ACCEPTED,
                )

        try:
            refund = create_refund(return_request=rr, amount=amount, method=method)
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        if method == ReturnRequest.RefundMethod.WALLET:
            refund = process_wallet_refund(refund=refund)
            if refund.status != Refund.Status.COMPLETED:
                return Response(
                    {'error': refund.failure_reason or 'Wallet refund failed.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            with transaction.atomic():
                rr.status = ReturnRequest.Status.REFUNDED
                rr.save(update_fields=['status', 'updated_at'])
                FinancialService.debit_for_refund(refund)

            return Response(ReturnRequestSerializer(rr).data)

        # ORIGINAL method: initiate via SSLCommerz refund API (async completion).
        refund.provider = 'SSLCOMMERZ'
        refund.provider_trans_id = f"TRID{refund.id}{uuid.uuid4().hex}"[:30]
        refund.save(update_fields=['provider', 'provider_trans_id'])

        client = SSLCommerzRefundClient()
        init_res = client.initiate_refund(
            bank_tran_id=rr.order.bank_tran_id,
            refund_trans_id=refund.provider_trans_id,
            refund_amount=Decimal(str(refund.amount)),
            refund_remarks=f"Refund for {rr.rma_number}",
            refe_id=str(refund.id),
        )

        if init_res.api_connect != 'DONE':
            refund.status = Refund.Status.FAILED
            refund.failure_reason = init_res.error_reason or f'APIConnect={init_res.api_connect}'
            refund.save(update_fields=['status', 'failure_reason', 'updated_at'])
            return Response(
                {'error': refund.failure_reason or 'Failed to initiate refund.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if init_res.status in ('success', 'processing'):
            if not init_res.refund_ref_id:
                refund.status = Refund.Status.FAILED
                refund.failure_reason = init_res.error_reason or 'Missing refund_ref_id from SSLCommerz.'
                refund.save(update_fields=['status', 'failure_reason', 'updated_at'])
                return Response(
                    {'error': refund.failure_reason},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            refund.status = Refund.Status.PROCESSING
            refund.provider_ref_id = init_res.refund_ref_id
            refund.save(update_fields=['status', 'provider_ref_id', 'updated_at'])

            rr.status = ReturnRequest.Status.REFUND_PENDING
            rr.save(update_fields=['status', 'updated_at'])

            # Fire-and-forget poll (also covered by periodic task if configured).
            try:
                from .tasks import poll_sslcommerz_refund_status  # local import avoids celery in import path
                poll_sslcommerz_refund_status.delay(refund.id)
            except Exception:
                pass

            return Response(
                ReturnRequestSerializer(rr).data,
                status=status.HTTP_202_ACCEPTED,
            )

        refund.status = Refund.Status.FAILED
        refund.failure_reason = init_res.error_reason or 'Refund request failed to initiate.'
        refund.save(update_fields=['status', 'failure_reason', 'updated_at'])
        return Response(
            {'error': refund.failure_reason},
            status=status.HTTP_400_BAD_REQUEST,
        )


class VendorCompleteRefundView(generics.GenericAPIView):
    """
    Manually marks the latest in-flight ORIGINAL-method refund as completed.
    This is a fallback path if automated gateway status tracking is unavailable.
    """

    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorRefundCompleteSerializer

    def post(self, request, pk, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            vendor = request.user.vendor_profile
            rr = ReturnRequest.objects.get(id=pk, vendor=vendor)
        except (AttributeError, ReturnRequest.DoesNotExist):
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if rr.status != ReturnRequest.Status.REFUND_PENDING:
            return Response({'error': 'Return is not awaiting refund completion.'}, status=status.HTTP_400_BAD_REQUEST)

        refund = (
            rr.refunds.filter(
                method=ReturnRequest.RefundMethod.ORIGINAL,
                status__in=[Refund.Status.PENDING, Refund.Status.PROCESSING],
            )
            .order_by('-created_at')
            .first()
        )
        if not refund:
            return Response({'error': 'No in-flight original-method refund found.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            refund.status = Refund.Status.COMPLETED
            refund.processed_at = timezone.now()
            refund.reference = serializer.validated_data.get('reference', '')
            refund.save(update_fields=['status', 'processed_at', 'reference'])

            rr.status = ReturnRequest.Status.REFUNDED
            rr.save(update_fields=['status', 'updated_at'])

            # Debit the vendor's ledger for the completed refund.
            FinancialService.debit_for_refund(refund)

        return Response(ReturnRequestSerializer(rr).data)


class VendorReturnPolicyListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorReturnPolicySerializer

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return ReturnPolicy.objects.none()
        return ReturnPolicy.objects.filter(vendor=vendor).order_by('-updated_at')


class VendorReturnPolicyDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VendorReturnPolicySerializer

    def get_queryset(self):
        try:
            vendor = self.request.user.vendor_profile
        except AttributeError:
            return ReturnPolicy.objects.none()
        return ReturnPolicy.objects.filter(vendor=vendor)
