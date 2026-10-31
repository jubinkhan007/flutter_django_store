import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../domain/entities/search_suggestion.dart';
import '../providers/product_provider.dart';
import '../../../vendor/presentation/screens/public_vendor_store_screen.dart';
import '../screens/product_detail_screen.dart';
import 'filter_bottom_sheet.dart';

class SearchOverlay extends StatefulWidget {
  final Future<void> Function() onSearchCleared;

  const SearchOverlay({super.key, required this.onSearchCleared});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    provider.loadSearchHistory();

    final query = provider.searchQuery;
    if (query != null && query.isNotEmpty) {
      _searchController.text = query;
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isOverlayOpen = true);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (query.isNotEmpty) {
        context.read<ProductProvider>().fetchSuggestions(query);
      } else {
        setState(() {});
      }
    });
  }

  void _executeSearch(String query) {
    _focusNode.unfocus();
    setState(() => _isOverlayOpen = false);
    _searchController.text = query;
    context.read<ProductProvider>().setSearchQuery(query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildSuggestionIcon(String type) {
    switch (type) {
      case 'PRODUCT':
        return const Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.lightTextSecondary,
        );
      case 'CATEGORY':
        return const Icon(
          Icons.category_outlined,
          color: AppColors.lightTextSecondary,
        );
      case 'VENDOR':
        return const Icon(
          Icons.storefront_outlined,
          color: Colors.purple,
        );
      case 'BRAND':
        return const Icon(
          Icons.verified_outlined,
          color: Colors.teal,
        );
      default:
        return const Icon(Icons.search, color: AppColors.lightTextSecondary);
    }
  }

  Future<void> _handleSuggestionTap(SearchSuggestion suggestion) async {
    _focusNode.unfocus();
    setState(() => _isOverlayOpen = false);

    if (suggestion.type == 'PRODUCT') {
      try {
        final product = await context
            .read<ProductProvider>()
            .getProductDetail(suggestion.id);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load product')),
        );
      }
    } else if (suggestion.type == 'CATEGORY') {
      _searchController.clear();
      context.read<ProductProvider>().clearFilters();
      context.read<ProductProvider>().selectCategory(suggestion.id);
    } else if (suggestion.type == 'VENDOR') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicVendorStoreScreen(vendorId: suggestion.id),
        ),
      );
    } else if (suggestion.type == 'BRAND') {
      _searchController.text = suggestion.label;
      final provider = context.read<ProductProvider>();
      provider.clearFilters();
      provider.toggleBrand(suggestion.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final activeCount = provider.activeFilterCount;

    return Column(
      children: [
        // Search Bar Row
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _isOverlayOpen
                    ? IconButton(
                        key: const ValueKey('back_button'),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _focusNode.unfocus();
                          setState(() => _isOverlayOpen = false);
                        },
                      )
                    : const SizedBox.shrink(key: ValueKey('no_back_button')),
              ),
              Expanded(
                key: const ValueKey('search_input_expanded'),
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    onSubmitted: _executeSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search products, brands, stores...',
                      prefixIcon: !_isOverlayOpen
                          ? const Icon(
                              Icons.search,
                              color: AppColors.lightTextSecondary,
                            )
                          : null,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.lightTextSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                if (!_isOverlayOpen) {
                                  widget.onSearchCleared();
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              if (!_isOverlayOpen) ...[
                const SizedBox(width: AppSpacing.sm),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: activeCount > 0
                            ? AppColors.primary
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: activeCount > 0
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const FilterBottomSheet(),
                          );
                        },
                      ),
                    ),
                    if (activeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              '$activeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Quick Active Filter Badges Bar (when not in overlay and filters applied)
        if (!_isOverlayOpen && (activeCount > 0 || provider.searchQuery != null))
          _buildQuickFilterBar(provider),

        // Overlay Content
        if (_isOverlayOpen)
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _searchController.text.trim().length >= 2
                ? _buildSuggestions(provider)
                : _buildHistoryAndTrending(provider),
          ),
      ],
    );
  }

  Widget _buildQuickFilterBar(ProductProvider provider) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // Filter button chip
          ActionChip(
            avatar: Icon(Icons.filter_list, size: 16, color: AppColors.primary),
            label: Text(
              'Filters (${provider.activeFilterCount})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            side: BorderSide(color: AppColors.primary),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const FilterBottomSheet(),
              );
            },
          ),
          const SizedBox(width: 8),

          // In-stock quick toggle
          FilterChip(
            label: const Text('In Stock Only', style: TextStyle(fontSize: 12)),
            selected: provider.inStockOnly,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            onSelected: (val) {
              provider.setInStockOnly(val);
            },
          ),
          const SizedBox(width: 8),

          // Selected brands chips
          ...provider.selectedBrands.map((brand) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(brand, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => provider.toggleBrand(brand),
              backgroundColor: Colors.teal.withValues(alpha: 0.12),
              side: BorderSide(color: Colors.teal.shade200),
            ),
          )),

          // Min rating chip
          if (provider.minRating != null) ...[
            Chip(
              label: Text('⭐ ${provider.minRating?.toInt()}★ & up', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => provider.setMinRating(null),
              backgroundColor: Colors.amber.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),
          ],

          // Min discount chip
          if (provider.minDiscount != null) ...[
            Chip(
              label: Text('🏷️ ≥${provider.minDiscount}% Off', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => provider.setMinDiscount(null),
              backgroundColor: Colors.orange.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),
          ],

          // Reset all chip
          ActionChip(
            label: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppColors.error)),
            onPressed: () => provider.clearFilters(),
            backgroundColor: Colors.red.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryAndTrending(ProductProvider provider) {
    final recent = provider.recentSearches;
    final trending = provider.trendingSearches;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Recent Searches Section
        if (recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton(
                onPressed: () => provider.clearRecentSearches(),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ],
          ),
          ...recent.take(6).map(
            (query) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.history,
                color: AppColors.lightTextSecondary,
                size: 20,
              ),
              title: Text(query, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(
                Icons.north_west,
                size: 16,
                color: AppColors.lightTextSecondary,
              ),
              onTap: () {
                _searchController.text = query;
                _executeSearch(query);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Trending Searches Section
        if (trending.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Trending Searches',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trending.map((item) {
              return ActionChip(
                label: Text(item, style: const TextStyle(fontSize: 13)),
                backgroundColor: Colors.grey.shade100,
                side: BorderSide(color: Colors.grey.shade300),
                onPressed: () {
                  _searchController.text = item;
                  _executeSearch(item);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestions(ProductProvider provider) {
    if (provider.isSuggestionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.lightSurface,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "${_searchController.text}"',
              style: const TextStyle(color: AppColors.lightTextSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = provider.suggestions[index];
        return ListTile(
          leading: _buildSuggestionIcon(suggestion.type),
          title: Text(suggestion.label),
          subtitle: suggestion.subtitle.isNotEmpty
              ? Text(suggestion.subtitle)
              : null,
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.lightSurface,
          ),
          onTap: () => _handleSuggestionTap(suggestion),
        );
      },
    );
  }
}
