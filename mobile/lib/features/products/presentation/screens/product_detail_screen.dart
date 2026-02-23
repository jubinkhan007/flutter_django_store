import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/product.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Image AppBar ──
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.surfaceLight,
                child: product.image != null
                    ? Image.network(
                        product.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: AppTheme.textSecondary,
                            size: 80,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppTheme.textSecondary,
                          size: 80,
                        ),
                      ),
              ),
            ),
          ),

          // ── Product Details ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),

                  // Stock Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.inStock
                              ? AppTheme.success.withOpacity(0.15)
                              : AppTheme.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          product.inStock ? 'In Stock' : 'Out of Stock',
                          style: TextStyle(
                            color: product.inStock
                                ? AppTheme.success
                                : AppTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${product.stockQuantity} available',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    product.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom Add to Cart Bar ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(color: AppTheme.surfaceLight, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: CustomButton(
            text: product.inStock ? 'Add to Cart' : 'Out of Stock',
            onPressed: product.inStock
                ? () {
                    context.read<CartProvider>().addToCart(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}
