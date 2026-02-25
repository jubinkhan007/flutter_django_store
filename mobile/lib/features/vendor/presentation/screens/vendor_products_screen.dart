import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../providers/vendor_provider.dart';
import 'vendor_add_product_screen.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VendorAddProductScreen(),
                      ),
                    );
                    if (mounted) {
                      context.read<VendorProvider>().loadProducts();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppGradients.darkPrimary
                              : AppGradients.lightPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Product List ──
          Expanded(
            child: Consumer<VendorProvider>(
              builder: (context, vendor, _) {
                if (vendor.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                }

                if (vendor.products.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.lightTextSecondary,
                          size: 48,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No products yet',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tap + to add your first product',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () => vendor.loadProducts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: vendor.products.length,
                    itemBuilder: (context, index) {
                      final product = vendor.products[index];
                      return Dismissible(
                        key: ValueKey(product.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.lightSurface,
                              title: const Text('Delete Product'),
                              content: Text(
                                'Are you sure you want to delete "${product.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) => vendor.deleteProduct(product.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(30),
                            borderRadius: BorderRadius.circular(
                              AppRadius.md,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.md,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Product thumbnail
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  image: product.image != null
                                      ? DecorationImage(
                                          image: NetworkImage(product.image!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: product.image == null
                                    ? const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: AppColors.lightTextSecondary,
                                        size: 24,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '\$${product.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Stock: ${product.stockQuantity}',
                                          style: const TextStyle(
                                            color: AppColors.lightTextSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Edit Button
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.lightTextSecondary,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VendorAddProductScreen(
                                        initialProduct: product,
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    context
                                        .read<VendorProvider>()
                                        .loadProducts();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
