import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/typography.dart';

import '../providers/vendor_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../cart/presentation/providers/cart_provider.dart';

class PublicVendorStoreScreen extends StatefulWidget {
  final int vendorId;

  const PublicVendorStoreScreen({super.key, required this.vendorId});

  @override
  State<PublicVendorStoreScreen> createState() =>
      _PublicVendorStoreScreenState();
}

class _PublicVendorStoreScreenState extends State<PublicVendorStoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadPublicProfile(widget.vendorId);
      // Fetch products for this specific vendor
      // (Assuming product provider search can filter by vendor)
      context.read<ProductProvider>().clearFilters();
      context.read<ProductProvider>().setSearchQuery(null);
      // We need a way to filter products by vendorId in ProductProvider.
      // For now, load all and filter locally, or ideally add vendorId filter to getProducts.
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<VendorProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = provider.publicProfile;
          if (profile == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Storefront')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(provider.error ?? 'Failed to load store profile'),
                    TextButton(
                      onPressed: () =>
                          provider.loadPublicProfile(widget.vendorId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Header Image / App Bar
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    profile.storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      profile.coverImageUrl != null
                          ? Image.network(
                              profile.coverImageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(color: Theme.of(context).primaryColor),
                      // Gradient overlay for text readability
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Store Info Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: profile.logoUrl != null
                                ? NetworkImage(profile.logoUrl!)
                                : null,
                            child: profile.logoUrl == null
                                ? const Icon(Icons.storefront, size: 30)
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Rating & Stats
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.avgRating.toStringAsFixed(1),
                                      style: AppTextStyles.titleLarge,
                                    ),
                                    Text(
                                      ' (${profile.reviewCount} reviews)',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Joined ${profile.joinedAt.year}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Description
                      if (profile.description.isNotEmpty) ...[
                        Text(
                          profile.description,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Policy Summary
                      if (profile.policySummary != null &&
                          profile.policySummary!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 20,
                                color: AppColors.lightTextSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  profile.policySummary!,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Store Products', style: AppTextStyles.titleMedium),
                    ],
                  ),
                ),
              ),

              // Product Grid
              Consumer<ProductProvider>(
                builder: (context, productProvider, _) {
                  // Filter products by vendorId locally for now.
                  // Ideally, the API handles this via ?vendor_id= query param.
                  final vendorProducts = productProvider.products
                      .where((p) => p.vendorId == widget.vendorId)
                      .toList();

                  if (productProvider.isLoading) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (vendorProducts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: Text('No products available from this store.'),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = vendorProducts[index];
                        return ProductCard(
                          product: product,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: product),
                              ),
                            );
                          },
                          onAddToCart: () {
                            context.read<CartProvider>().addToCart(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} added to cart'),
                                backgroundColor: Theme.of(context).primaryColor,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      }, childCount: vendorProducts.length),
                    ),
                  );
                },
              ),

              // Bottom Padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}
