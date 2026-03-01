import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../providers/product_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  double _minPrice = 0;
  double _maxPrice = 5000;
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    _minPrice = provider.minPrice ?? 0;
    _maxPrice = provider.maxPrice ?? 5000;
    _sortBy = provider.sortBy ?? 'newest';
  }

  void _applyFilters() {
    final provider = context.read<ProductProvider>();
    final min = _minPrice <= 0 ? null : _minPrice;
    final max = _maxPrice >= 5000 ? null : _maxPrice;
    provider.setPriceRange(min, max);
    provider.setSortBy(_sortBy == 'newest' ? null : _sortBy);
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
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
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
                  color: AppColors.lightTextPrimary,
                ),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Reset',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Sort By ──
          const Text(
            'Sort By',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              _buildSortChip('Newest', 'newest'),
              _buildSortChip('Price: Low to High', 'price_asc'),
              _buildSortChip('Price: High to Low', 'price_desc'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Price Range ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Price Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              Text(
                '\$${_minPrice.toInt()} - \$${_maxPrice.toInt()}',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RangeSlider(
            values: RangeValues(_minPrice, _maxPrice),
            min: 0,
            max: 5000,
            divisions: 100,
            activeColor: Theme.of(context).primaryColor,
            inactiveColor: AppColors.lightSurface,
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
          const SizedBox(height: AppSpacing.xl),

          // ── Apply Button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      backgroundColor: AppColors.lightSurface,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).primaryColor
            : AppColors.lightTextSecondary,
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
