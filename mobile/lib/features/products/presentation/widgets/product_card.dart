import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../products/domain/entities/product.dart';

/// Reusable product card used in the home screen grid.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.surfaceLight, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ──
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: Center(
                  child: product.image != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusMd),
                          ),
                          child: Image.network(
                            product.image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_outlined,
                              color: AppTheme.textSecondary,
                              size: 40,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppTheme.textSecondary,
                          size: 40,
                        ),
                ),
              ),
            ),

            // ── Product Info ──
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
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
