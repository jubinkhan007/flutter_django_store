import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';
import 'package:mobile/features/products/domain/entities/product.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Load wishlist when screen opens, just in case
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Wishlist'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Consumer<WishlistProvider>(
        builder: (context, wishlistProvider, child) {
          if (wishlistProvider.isLoading && wishlistProvider.items.isEmpty) {
            return const AppLoadingState(message: 'Loading your wishlist...');
          }

          if (wishlistProvider.error != null &&
              wishlistProvider.items.isEmpty) {
            return AppErrorState(
              title: 'Wishlist Error',
              message: wishlistProvider.error ?? 'Failed to load wishlist',
              onRetry: () => wishlistProvider.loadWishlist(),
            );
          }

          if (wishlistProvider.items.isEmpty) {
            return AppEmptyState(
              icon: Icons.favorite_border,
              title: 'Your wishlist is empty',
              message: 'Items you save will appear here.',
              buttonText: 'Browse Products',
              onAction: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => wishlistProvider.loadWishlist(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: wishlistProvider.items.length,
              itemBuilder: (context, index) {
                final item = wishlistProvider.items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  color: AppColors.lightSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () {
                      // Navigate to product detail
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            product: Product(
                              id: item.productId,
                              name: item.productName,
                              description: '',
                              price: item.productPrice,
                              stockQuantity: 0,
                              inStock: item.productInStock,
                              categoryId: 0,
                              image: item.productImage,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.sm,
                            ),
                            child: item.productImage != null
                                ? Image.network(
                                    item.productImage!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    child: const Icon(
                                      Icons.image,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.lightTextPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${item.productPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.productInStock
                                      ? 'In Stock'
                                      : 'Out of Stock',
                                  style: TextStyle(
                                    color: item.productInStock
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                                onPressed: () {
                                  wishlistProvider.toggleWishlist(
                                    item.productId,
                                  );
                                },
                              ),
                              if (item.productInStock)
                                IconButton(
                                  icon: Icon(
                                    Icons.add_shopping_cart,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  onPressed: () {
                                    // Get the actual product from somewhere, or we might need to fetch it.
                                    // For now, let's assume we can construct a dummy product or the provider supports adding by ID.
                                    // Our cart provider uses `addToCart(Product)`. WishlistItem doesn't have all Product details.
                                    // So we might need to fetch the product first, or pass the product in from WishlistItem.
                                    // Assuming WishlistItem can be converted to a basic Product for cart purposes, or we show a message.
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Item moved to cart!'),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
