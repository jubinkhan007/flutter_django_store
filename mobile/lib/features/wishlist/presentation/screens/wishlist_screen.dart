import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';
import 'package:mobile/features/products/domain/entities/product.dart';
import 'package:mobile/features/products/presentation/providers/product_provider.dart';
import 'package:mobile/features/cart/presentation/providers/cart_provider.dart';
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
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
                                    () async {
                                      try {
                                        final productProvider =
                                            context.read<ProductProvider>();
                                        final cart =
                                            context.read<CartProvider>();

                                        final full = await productProvider
                                            .getProductDetail(item.productId);

                                        if (!context.mounted) return;

                                        if (full.options.isNotEmpty ||
                                            full.variants.isNotEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Select options before adding to cart',
                                              ),
                                            ),
                                          );
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProductDetailScreen(
                                                product: full,
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        cart.addToCart(full);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Added to cart'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to add: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }();
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
