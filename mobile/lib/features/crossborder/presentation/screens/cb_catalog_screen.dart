import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../data/models/cb_models.dart';
import '../providers/crossborder_provider.dart';
import 'cb_buy_by_link_screen.dart';
import 'cb_my_orders_screen.dart';
import 'cb_product_detail_screen.dart';

class CbCatalogScreen extends StatefulWidget {
  const CbCatalogScreen({super.key});

  @override
  State<CbCatalogScreen> createState() => _CbCatalogScreenState();
}

class _CbCatalogScreenState extends State<CbCatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CrossBorderProvider>().loadCatalog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Abroad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'My CB Orders',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CbMyOrdersScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CbBuyByLinkScreen()),
        ),
        icon: const Icon(Icons.link),
        label: const Text('Buy by Link'),
      ),
      body: Consumer<CrossBorderProvider>(
        builder: (context, provider, _) {
          if (provider.productsLoading) {
            return const AppLoadingState(message: 'Loading catalog...');
          }
          if (provider.productsError != null && provider.products.isEmpty) {
            return AppErrorState(
              title: 'Catalog Error',
              message: provider.productsError!,
              onRetry: () => provider.loadCatalog(),
            );
          }
          if (provider.products.isEmpty) {
            return const AppEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Catalog coming soon',
              message: 'No products in the catalog yet. Use "Buy by Link" to order anything from abroad.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadCatalog(),
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: provider.products.length,
              itemBuilder: (context, index) {
                final product = provider.products[index];
                return _CbProductCard(
                  product: product,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CbProductDetailScreen(product: product),
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

class _CbProductCard extends StatelessWidget {
  final CrossBorderProduct product;
  final VoidCallback onTap;

  const _CbProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: product.primaryImage.isNotEmpty
                  ? Image.network(
                      product.primaryImage,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Marketplace badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.originMarketplace,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.lightPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.currency} ${product.basePriceForeign.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.leadTimeDaysMin}–${product.leadTimeDaysMax} days',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: AppColors.lightSurface,
      child: const Icon(
        Icons.shopping_bag_outlined,
        size: 40,
        color: AppColors.lightTextSecondary,
      ),
    );
  }
}
