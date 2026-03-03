import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_recommendations.dart';
import '../../domain/entities/variant.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../screens/product_detail_screen.dart';

class ImpressionOnce extends StatefulWidget {
  final String eventType;
  final String source;
  final int? productId;
  final Map<String, dynamic>? metadata;
  final Duration delay;
  final Widget child;

  const ImpressionOnce({
    super.key,
    required this.eventType,
    required this.source,
    this.productId,
    this.metadata,
    this.delay = const Duration(milliseconds: 0),
    required this.child,
  });

  @override
  State<ImpressionOnce> createState() => _ImpressionOnceState();
}

class _ImpressionOnceState extends State<ImpressionOnce> {
  bool _sent = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  void _schedule() {
    if (_sent || !mounted) return;
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (!mounted || _sent) return;
      _sent = true;
      context.read<AnalyticsService>().logEvent(
        eventType: widget.eventType,
        source: widget.source,
        productId: widget.productId,
        metadata: widget.metadata,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class FrequentlyBoughtTogetherCard extends StatefulWidget {
  final int anchorProductId;

  const FrequentlyBoughtTogetherCard({super.key, required this.anchorProductId});

  @override
  State<FrequentlyBoughtTogetherCard> createState() =>
      _FrequentlyBoughtTogetherCardState();
}

class _FrequentlyBoughtTogetherCardState
    extends State<FrequentlyBoughtTogetherCard> {
  late Future<ProductRecommendations> _future;

  @override
  void initState() {
    super.initState();
    _future = context
        .read<DiscoveryRepository>()
        .getProductRecommendations(widget.anchorProductId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductRecommendations>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final fbt = snapshot.data!.frequentlyBoughtTogether;
        if (fbt.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Frequently bought together',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addAll(context, fbt),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add all'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: fbt.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final p = fbt[index];
                      return _MiniProductTile(
                        product: p,
                        onTap: () {
                          context.read<AnalyticsService>().logEvent(
                            eventType: 'CLICK',
                            source: 'PDP',
                            productId: p.id,
                            metadata: {
                              'bundle': 'FBT',
                              'position': index,
                              'anchor_product_id': widget.anchorProductId,
                            },
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(product: p),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addAll(BuildContext context, List<Product> products) async {
    final cart = context.read<CartProvider>();
    final analytics = context.read<AnalyticsService>();

    int added = 0;
    for (final p in products) {
      if (!p.isAvailable) continue;

      final needsVariant = p.options.isNotEmpty && p.variants.isNotEmpty;
      ProductVariant? variant;
      if (needsVariant) {
        variant = await _selectVariant(context, p);
        if (!context.mounted) return;
        if (variant == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Variant selection cancelled')),
          );
          return;
        }
      }

      cart.addToCart(p, variant: variant);
      added++;
      await analytics.logEvent(
        eventType: 'ADD_TO_CART',
        source: 'PDP',
        productId: p.id,
        metadata: {
          'bundle': 'FBT',
          'anchor_product_id': widget.anchorProductId,
        },
      );
    }

    if (!context.mounted) return;
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added item(s) to cart'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<ProductVariant?> _selectVariant(BuildContext context, Product product) {
    return showModalBottomSheet<ProductVariant?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VariantSelectorSheet(product: product),
    );
  }
}

class _MiniProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _MiniProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.black12),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '\$${product.effectivePrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantSelectorSheet extends StatefulWidget {
  final Product product;

  const _VariantSelectorSheet({required this.product});

  @override
  State<_VariantSelectorSheet> createState() => _VariantSelectorSheetState();
}

class _VariantSelectorSheetState extends State<_VariantSelectorSheet> {
  final Map<int, int> _selectedOptions = {};
  ProductVariant? _currentVariant;

  @override
  void initState() {
    super.initState();
    for (final option in widget.product.options) {
      if (option.values.isNotEmpty) {
        _selectedOptions[option.id] = option.values.first.id;
      }
    }
    _updateCurrentVariant();
  }

  void _updateCurrentVariant() {
    if (widget.product.variants.isEmpty) {
      _currentVariant = null;
      return;
    }

    final selectedValueIds = _selectedOptions.values.toSet();
    try {
      _currentVariant = widget.product.variants.firstWhere((variant) {
        final variantValueIds = variant.optionValueIds.toSet();
        return selectedValueIds.length == variantValueIds.length &&
            selectedValueIds.containsAll(variantValueIds);
      });
    } catch (_) {
      _currentVariant = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...widget.product.options.map((option) {
              final selectedId = _selectedOptions[option.id];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: option.values.map((v) {
                        final selected = v.id == selectedId;
                        return ChoiceChip(
                          label: Text(v.value),
                          selected: selected,
                          onSelected: (_) {
                            _selectedOptions[option.id] = v.id;
                            _updateCurrentVariant();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentVariant == null
                        ? null
                        : () => Navigator.pop(context, _currentVariant),
                    child: Text(
                      _currentVariant == null
                          ? 'Unavailable'
                          : 'Add this variant',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

