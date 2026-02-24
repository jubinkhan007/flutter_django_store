from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError
from django.shortcuts import get_object_or_404

from products.models import Product
from .models import Review, ReviewReply
from .serializers import ReviewSerializer, ReviewReplySerializer


class ProductReviewListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/products/<pk>/reviews/ — public list of reviews for a product
    POST /api/products/<pk>/reviews/ — authenticated customer submits a review
    """
    serializer_class = ReviewSerializer

    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return (
            Review.objects
            .filter(product_id=self.kwargs['pk'])
            .select_related('customer', 'reply__vendor')
        )

    def perform_create(self, serializer):
        product = get_object_or_404(Product, pk=self.kwargs['pk'])
        if Review.objects.filter(customer=self.request.user, product=product).exists():
            raise ValidationError('You have already reviewed this product.')
        serializer.save(customer=self.request.user, product=product)


class ReviewReplyView(generics.GenericAPIView):
    """
    POST  /api/reviews/<pk>/reply/ — vendor posts a reply to a review
    PATCH /api/reviews/<pk>/reply/ — vendor edits their existing reply
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ReviewReplySerializer

    def _get_vendor_and_review(self, request, pk):
        try:
            vendor = request.user.vendor_profile
        except Exception:
            return None, None, Response(
                {'error': 'Only vendors can reply to reviews.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        review = get_object_or_404(Review, pk=pk)
        if review.product.vendor != vendor:
            return None, None, Response(
                {'error': 'You can only reply to reviews on your own products.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return vendor, review, None

    def post(self, request, pk, *args, **kwargs):
        vendor, review, err = self._get_vendor_and_review(request, pk)
        if err:
            return err
        if hasattr(review, 'reply'):
            return Response(
                {'error': 'You have already replied. Use PATCH to edit.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = ReviewReplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(review=review, vendor=vendor)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def patch(self, request, pk, *args, **kwargs):
        vendor, review, err = self._get_vendor_and_review(request, pk)
        if err:
            return err
        if not hasattr(review, 'reply') or review.reply.vendor != vendor:
            return Response(
                {'error': 'Reply not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = ReviewReplySerializer(review.reply, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)
