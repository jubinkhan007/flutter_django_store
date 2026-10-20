from __future__ import annotations

from decimal import Decimal
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import LoyaltyAccount, LoyaltyTransaction
from .serializers import (
    LoyaltyAccountSummarySerializer,
    LoyaltyTransactionSerializer,
    QuoteRedemptionSerializer,
)


class LoyaltySummaryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        account, _ = LoyaltyAccount.objects.get_or_create(user=request.user)
        serializer = LoyaltyAccountSummarySerializer(account, context={'request': request})
        return Response(serializer.data)


class LoyaltyTransactionsListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = LoyaltyTransactionSerializer

    def get_queryset(self):
        account, _ = LoyaltyAccount.objects.get_or_create(user=self.request.user)
        return account.transactions.all()


class QuoteRedemptionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = QuoteRedemptionSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)

        points = serializer.validated_data['points']
        account, _ = LoyaltyAccount.objects.get_or_create(user=request.user)

        discount_amount = (Decimal(points) / Decimal(account.POINTS_PER_BDT)).quantize(Decimal('0.01'))
        remaining_balance = account.points_balance - points

        return Response({
            'points': points,
            'points_redeemed': points,
            'discount_amount': str(discount_amount),
            'available_points': account.points_balance,
            'remaining_balance': remaining_balance,
        })
