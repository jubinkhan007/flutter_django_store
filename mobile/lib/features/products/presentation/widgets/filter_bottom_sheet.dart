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
  double _maxPrice = 10000;
  String _sortBy = 'newest';
  final Set<String> _selectedBrands = {};
  double? _minRating;
  int? _minDiscount;
  bool _inStockOnly = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    final facets = provider.facets;
    final maxAllowed = (facets != null && facets.priceRange.max > 0)
        ? facets.priceRange.max
        : 10000.0;

    _minPrice = provider.minPrice ?? 0;
    _maxPrice = provider.maxPrice ?? maxAllowed;
    if (_maxPrice < _minPrice) _maxPrice = maxAllowed;
    _sortBy = provider.sortBy ?? 'newest';
    _selectedBrands.addAll(provider.selectedBrands);
    _minRating = provider.minRating;
    _minDiscount = provider.minDiscount;
    _inStockOnly = provider.inStockOnly;
  }

  void _applyFilters() {
    final provider = context.read<ProductProvider>();
    final facets = provider.facets;
    final maxAllowed = (facets != null && facets.priceRange.max > 0)
        ? facets.priceRange.max
        : 10000.0;

    final min = _minPrice <= 0 ? null : _minPrice;
    final max = _maxPrice >= maxAllowed ? null : _maxPrice;

    provider.applyAdvancedFilters(
      sortBy: _sortBy == 'newest' ? null : _sortBy,
      brands: _selectedBrands.toList(),
      minPrice: min,
      maxPrice: max,
      minRating: _minRating,
      minDiscount: _minDiscount,
      inStockOnly: _inStockOnly,
    );
    Navigator.pop(context);
  }

  void _clearFilters() {
    final provider = context.read<ProductProvider>();
    provider.clearFilters();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final facets = provider.facets;
    final maxSliderVal = (facets != null && facets.priceRange.max > 100)
        ? facets.priceRange.max
        : 10000.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Filters & Sort',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                        if (provider.activeFilterCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${provider.activeFilterCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text(
                        'Reset All',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable filter sections
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    // ── Sort By ──
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('🔥 Popular / Best Selling', 'popularity'),
                        _buildSortChip('⭐ Top Rated', 'rating'),
                        _buildSortChip('🏷️ Highest Discount', 'discount'),
                        _buildSortChip('✨ Newest', 'newest'),
                        _buildSortChip('💰 Price: Low to High', 'price_asc'),
                        _buildSortChip('💎 Price: High to Low', 'price_desc'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── In Stock Only ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _inStockOnly ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _inStockOnly ? AppColors.primary : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: _inStockOnly ? AppColors.primary : Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'In Stock Only',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _inStockOnly ? AppColors.primary : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (facets != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${facets.inStockCount})',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          Switch.adaptive(
                            value: _inStockOnly,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _inStockOnly = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Price Range ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Price Range (BDT)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          '৳${_minPrice.toInt()} - ৳${_maxPrice.toInt()}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(
                        _minPrice.clamp(0.0, maxSliderVal),
                        _maxPrice.clamp(0.0, maxSliderVal),
                      ),
                      min: 0,
                      max: maxSliderVal,
                      divisions: 100,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.grey.shade200,
                      labels: RangeLabels(
                        '৳${_minPrice.toInt()}',
                        '৳${_maxPrice.toInt()}',
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _minPrice = values.start;
                          _maxPrice = values.end;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Minimum Customer Rating ──
                    const Text(
                      'Minimum Rating',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _buildRatingChip(null, 'All Ratings'),
                        const SizedBox(width: 8),
                        _buildRatingChip(4.0, '4★ & up', count: facets?.ratingCounts.fourPlus),
                        const SizedBox(width: 8),
                        _buildRatingChip(3.0, '3★ & up', count: facets?.ratingCounts.threePlus),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Minimum Discount ──
                    const Text(
                      'Discount Offer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDiscountChip(null, 'All Items'),
                        _buildDiscountChip(10, '10% or more', count: facets?.discountCounts.tenPlus),
                        _buildDiscountChip(25, '25% or more', count: facets?.discountCounts.twentyFivePlus),
                        _buildDiscountChip(50, '50% or more', count: facets?.discountCounts.fiftyPlus),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Brands ──
                    if (facets != null && facets.brands.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Brands',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          if (_selectedBrands.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedBrands.clear();
                                });
                              },
                              child: const Text(
                                'Clear Brands',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: facets.brands.map((b) {
                          final isSelected = _selectedBrands.contains(b.name);
                          return FilterChip(
                            label: Text(
                              '${b.name} (${b.count})',
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white : AppColors.lightTextPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedBrands.add(b.name);
                                } else {
                                  _selectedBrands.remove(b.name);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ],
                ),
              ),

              // ── Apply Action Bar ──
              Container(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.md,
                  bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: _applyFilters,
                    child: Text(
                      facets != null
                          ? 'Apply Filters (${facets.totalCount} Products)'
                          : 'Apply Filters',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.lightTextPrimary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = value;
          });
        }
      },
    );
  }

  Widget _buildRatingChip(double? rating, String label, {int? count}) {
    final isSelected = _minRating == rating;
    return ChoiceChip(
      label: Text(
        count != null ? '$label ($count)' : label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.lightTextPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        setState(() {
          _minRating = rating;
        });
      },
    );
  }

  Widget _buildDiscountChip(int? discount, String label, {int? count}) {
    final isSelected = _minDiscount == discount;
    return ChoiceChip(
      label: Text(
        count != null ? '$label ($count)' : label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.lightTextPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        setState(() {
          _minDiscount = discount;
        });
      },
    );
  }
}
