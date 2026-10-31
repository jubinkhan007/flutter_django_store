import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../products/domain/entities/product.dart';
import 'package:mobile/features/wishlist/presentation/providers/wishlist_provider.dart';
import '../../../../core/services/ad_tracking_service.dart';

/// Reusable product card used in the storefront and search grids.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? salePrice;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.salePrice,
  });

  @override
  Widget build(BuildContext context) {
    if (product.isSponsored && product.campaignId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AdTrackingService().recordImpression(product.campaignId!);
      });
    }

    final effectivePrice = salePrice ?? product.effectivePrice;
    final hasDiscount = effectivePrice < product.price;
    final discountPercent = product.discountPercent > 0
        ? product.discountPercent
        : (hasDiscount && product.price > 0
            ? (((product.price - effectivePrice) / product.price) * 100).round()
            : 0);

    return GestureDetector(
      onTap: () {
        if (product.isSponsored && product.campaignId != null) {
          AdTrackingService().recordClick(product.campaignId!);
        }
        onTap?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.lightOutline, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image & Floating Badges ──
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.lightBg,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.md),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: product.image != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.md),
                              ),
                              child: Image.network(
                                product.image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.lightTextSecondary,
                                  size: 40,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.lightTextSecondary,
                              size: 40,
                            ),
                    ),

                    // Badges stack (Top Left: Sponsored & Discount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.isSponsored) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha((0.7 * 255).round()),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Sponsored',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (discountPercent > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-$discountPercent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Wishlist Heart Icon
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Consumer<WishlistProvider>(
                        builder: (context, wishlist, child) {
                          final isWishlisted = wishlist.isWishlisted(
                            product.id,
                          );
                          return IconButton(
                            icon: Icon(
                              isWishlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isWishlisted
                                  ? Colors.red
                                  : AppColors.lightTextSecondary,
                            ),
                            onPressed: () {
                              wishlist.toggleWishlist(
                                product.id,
                                productDetails: {
                                  'name': product.name,
                                  'price': product.price,
                                  'image': product.image,
                                  'inStock': product.inStock,
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Product Info ──
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand (if present) & Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.brand.isNotEmpty)
                          Text(
                            product.brand.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.lightTextPrimary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),

                    // Rating & Price row
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.avgRating > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 12, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  product.avgRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (product.reviewCount > 0) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    '(${product.reviewCount})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasDiscount)
                                    Text(
                                      '৳${product.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  Text(
                                    '৳${effectivePrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: hasDiscount
                                          ? AppColors.error
                                          : Theme.of(context).primaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (onAddToCart != null)
                              GestureDetector(
                                onTap: onAddToCart,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.lightPrimary,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
