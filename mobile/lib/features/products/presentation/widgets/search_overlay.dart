import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../domain/entities/search_suggestion.dart';
import '../providers/product_provider.dart';
import '../../../vendor/presentation/screens/public_vendor_store_screen.dart';
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
  List<String> _recentSearches = [];

  static const _historyKey = 'search_history';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    final query = context.read<ProductProvider>().searchQuery;
    if (query != null && query.isNotEmpty) {
      _searchController.text = query;
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isOverlayOpen = true);
      }
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _saveToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 5) {
      _recentSearches = _recentSearches.sublist(0, 5);
    }
    await prefs.setStringList(_historyKey, _recentSearches);
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() {
      _recentSearches = [];
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        context.read<ProductProvider>().fetchSuggestions(query);
      } else {
        setState(() {}); // trigger rebuild to show history
      }
    });
  }

  void _executeSearch(String query) {
    _focusNode.unfocus();
    setState(() => _isOverlayOpen = false);
    _saveToHistory(query);
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
          color: ThemeMode.system == ThemeMode.dark
              ? Colors.purpleAccent
              : Colors.purple,
        );
      default:
        return const Icon(Icons.search, color: AppColors.lightTextSecondary);
    }
  }

  void _handleSuggestionTap(SearchSuggestion suggestion) {
    _focusNode.unfocus();
    setState(() => _isOverlayOpen = false);

    if (suggestion.type == 'PRODUCT') {
      _executeSearch(
        suggestion.label,
      ); // Navigate to product logic typically handled by list click, here we execute search to show it in the list.
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final hasActiveFilters =
        provider.minPrice != null ||
        provider.maxPrice != null ||
        (provider.sortBy != null && provider.sortBy != 'newest');

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              if (_isOverlayOpen)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _focusNode.unfocus();
                    setState(() => _isOverlayOpen = false);
                  },
                ),
              Expanded(
                child: Hero(
                  tag: 'search_bar',
                  child: Material(
                    type: MaterialType.transparency,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      onSubmitted: _executeSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search products, stores...',
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
              ),
              if (!_isOverlayOpen) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: hasActiveFilters
                        ? Theme.of(context).primaryColor
                        : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: hasActiveFilters
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
              ],
            ],
          ),
        ),

        // Overlay Content
        if (_isOverlayOpen)
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _searchController.text.trim().length >= 2
                  ? _buildSuggestions(provider)
                  : _buildHistory(),
            ),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    if (_recentSearches.isEmpty) {
      return const Center(
        child: Text(
          'Search for products, categories, or stores',
          style: TextStyle(color: AppColors.lightTextSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
        ..._recentSearches.map(
          (query) => ListTile(
            leading: const Icon(
              Icons.history,
              color: AppColors.lightTextSecondary,
            ),
            title: Text(query),
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
