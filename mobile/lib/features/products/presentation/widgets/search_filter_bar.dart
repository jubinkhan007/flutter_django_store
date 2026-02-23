import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';
import 'filter_bottom_sheet.dart';

class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({super.key});

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill if there's an existing query in the provider
    final query = context.read<ProductProvider>().searchQuery;
    if (query != null) {
      _searchController.text = query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<ProductProvider>().setSearchQuery(
        query.isEmpty ? null : query,
      );
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    // Check if any advanced filters are active to show a badge or active state
    final hasActiveFilters =
        provider.minPrice != null ||
        provider.maxPrice != null ||
        (provider.sortBy != null && provider.sortBy != 'newest');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Container(
            decoration: BoxDecoration(
              color: hasActiveFilters
                  ? AppTheme.primary
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: IconButton(
              icon: Icon(
                Icons.tune,
                color: hasActiveFilters ? Colors.white : AppTheme.textPrimary,
              ),
              onPressed: _showFilterSheet,
            ),
          ),
        ],
      ),
    );
  }
}
