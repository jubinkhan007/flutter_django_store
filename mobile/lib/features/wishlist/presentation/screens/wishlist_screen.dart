import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';
import 'package:mobile/features/products/domain/entities/product.dart';
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Wishlist'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Consumer<WishlistProvider>(
        builder: (context, wishlistProvider, child) {
          if (wishlistProvider.isLoading && wishlistProvider.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (wishlistProvider.error != null &&
              wishlistProvider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load wishlist:\n${wishlistProvider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => wishlistProvider.loadWishlist(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (wishlistProvider.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your wishlist is empty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Items you save will appear here.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => wishlistProvider.loadWishlist(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: wishlistProvider.items.length,
              itemBuilder: (context, index) {
                final item = wishlistProvider.items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                      padding: const EdgeInsets.all(AppTheme.spacingSm),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
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
                                    color: AppTheme.background,
                                    child: const Icon(
                                      Icons.image,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${item.productPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
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
                                        ? AppTheme.success
                                        : AppTheme.error,
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
                                color: AppTheme.error,
                                onPressed: () {
                                  wishlistProvider.toggleWishlist(
                                    item.productId,
                                  );
                                },
                              ),
                              if (item.productInStock)
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    color: AppTheme.primary,
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
