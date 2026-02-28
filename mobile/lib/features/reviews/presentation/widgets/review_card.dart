import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/review_model.dart';
import '../../../../core/config/api_config.dart';
import '../providers/review_provider.dart';
import 'star_rating.dart';
import 'package:provider/provider.dart';

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isVendorOfProduct;
  final void Function(ReviewModel review, bool isEditing)? onReply;

  const ReviewCard({
    super.key,
    required this.review,
    this.isVendorOfProduct = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: username + rating + date
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).primaryColor.withAlpha(38),
                child: Text(
                  review.customerUsername.isNotEmpty
                      ? review.customerUsername[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerUsername,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    StarRating(rating: review.rating.toDouble(), size: 14),
                    if (review.isVerifiedPurchase)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified Purchase',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style: const TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          // Comment
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(
              color: AppColors.lightTextSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imageUrl = ApiConfig.resolveUrl(
                    review.images[index].imageUrl,
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(
                      imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.broken_image,
                          size: 24,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Vendor reply section
          if (review.reply != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).primaryColor.withAlpha(153),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review.reply!.vendorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const Spacer(),
                      if (isVendorOfProduct)
                        GestureDetector(
                          onTap: () => onReply?.call(review, true),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              color: AppColors.lightTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.reply!.reply,
                    style: const TextStyle(
                      color: AppColors.lightTextSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isVendorOfProduct) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => onReply?.call(review, false),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.reply,
                    size: 15,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Reply as vendor',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor.withAlpha(217),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${review.helpfulVotes} people found this helpful',
                style: const TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  context.read<ReviewProvider>().voteHelpful(review.id);
                },
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.thumb_up_outlined,
                        size: 16,
                        color: AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Helpful',
                        style: TextStyle(
                          color: AppColors.lightTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
