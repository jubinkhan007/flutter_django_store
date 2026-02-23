import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/product_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  double _minPrice = 0;
  double _maxPrice = 1000;
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    _minPrice = provider.minPrice ?? 0;
    _maxPrice = provider.maxPrice ?? 1000;
    _sortBy = provider.sortBy ?? 'newest';
  }

  void _applyFilters() {
    final provider = context.read<ProductProvider>();
    provider.setPriceRange(_minPrice, _maxPrice);
    provider.setSortBy(_sortBy);
    Navigator.pop(context);
  }

  void _clearFilters() {
    final provider = context.read<ProductProvider>();
    provider.clearFilters();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Reset',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // ── Sort By ──
          const Text(
            'Sort By',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Wrap(
            spacing: AppTheme.spacingSm,
            children: [
              _buildSortChip('Newest', 'newest'),
              _buildSortChip('Price: Low to High', 'price_asc'),
              _buildSortChip('Price: High to Low', 'price_desc'),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // ── Price Range ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Price Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '\$${_minPrice.toInt()} - \$${_maxPrice.toInt()}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          RangeSlider(
            values: RangeValues(_minPrice, _maxPrice),
            min: 0,
            max: 5000,
            divisions: 100,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.surfaceLight,
            labels: RangeLabels(
              '\$${_minPrice.toInt()}',
              '\$${_maxPrice.toInt()}',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                _minPrice = values.start;
                _maxPrice = values.end;
              });
            },
          ),
          const SizedBox(height: AppTheme.spacingXl),

          // ── Apply Button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (bool selected) {
        setState(() {
          _sortBy = value;
        });
      },
    );
  }
}
