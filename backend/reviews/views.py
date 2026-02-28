from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.exceptions import ValidationError
from django.shortcuts import get_object_or_404
from django.db.models import Count

from products.models import Product
from .models import Review, ReviewReply, ReviewImage, ReviewHelpfulness
from .serializers import ReviewSerializer, ReviewReplySerializer


class ProductReviewListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/products/<pk>/reviews/ — public list of reviews for a product
    POST /api/products/<pk>/reviews/ — authenticated customer submits a review
    """
    serializer_class = ReviewSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        return (
            Review.objects
            .filter(product_id=self.kwargs['pk'])
            .select_related('customer', 'reply__vendor')
            .prefetch_related('images')
            .annotate(helpful_votes_count=Count('helpful_votes'))
        )

    def perform_create(self, serializer):
        product = get_object_or_404(Product, pk=self.kwargs['pk'])
        if Review.objects.filter(customer=self.request.user, product=product).exists():
            raise ValidationError({'detail': 'You have already reviewed this product.'})

        # Attempt to link to a completed SubOrder for verified purchase
        from orders.models import SubOrder
        from django.db.models import Q
        sub_order = SubOrder.objects.filter(
            order__customer=self.request.user,
            status='DELIVERED',
        ).filter(
            Q(items__product=product) | Q(items__variant__product=product)
        ).distinct().first()

        is_verified = sub_order is not None

        # Handle image uploads
        images = self.request.FILES.getlist('images')
        if len(images) > 5:
            raise ValidationError("You can upload a maximum of 5 images per review.")

        review = serializer.save(
            customer=self.request.user,
            product=product,
            sub_order=sub_order,
            is_verified_purchase=is_verified
        )
        
        for idx, image in enumerate(images):
            ReviewImage.objects.create(review=review, image=image, position=idx)


class ReviewHelpfulVoteView(generics.GenericAPIView):
    """
    POST /api/reviews/<pk>/vote/
    Allows an authenticated user to mark a review as helpful.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        review = get_object_or_404(Review, pk=pk)
        
        if review.customer == request.user:
            return Response(
                {"error": "You cannot vote on your own review."},
                status=status.HTTP_400_BAD_REQUEST
            )

        vote, created = ReviewHelpfulness.objects.get_or_create(
            review=review,
            user=request.user,
        )

        if not created:
            return Response(
                {"error": "You have already voted on this review."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {"message": "Review marked as helpful."},
            status=status.HTTP_201_CREATED,
        )


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
