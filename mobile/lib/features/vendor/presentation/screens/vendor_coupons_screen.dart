import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../data/models/vendor_coupon_model.dart';
import '../providers/vendor_provider.dart';


class VendorCouponsScreen extends StatefulWidget {
  const VendorCouponsScreen({super.key});

  @override
  State<VendorCouponsScreen> createState() => _VendorCouponsScreenState();
}

class _VendorCouponsScreenState extends State<VendorCouponsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadCoupons();
      context.read<VendorProvider>().loadProducts();
      context.read<ProductProvider>().loadCategories();
    });
  }

  Future<void> _showCreateCouponSheet(BuildContext context) async {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final minController = TextEditingController();

    var discountType = 'PERCENT';
    final selectedProductIds = <int>{};
    final selectedCategoryIds = <int>{};

    Future<void> pickProducts() async {
      final vendor = context.read<VendorProvider>();
      final products = vendor.products;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select products'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: products
                    .map(
                      (p) => CheckboxListTile(
                        value: selectedProductIds.contains(p.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selectedProductIds.add(p.id);
                            } else {
                              selectedProductIds.remove(p.id);
                            }
                          });
                        },
                        title: Text(p.name),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> pickCategories() async {
      final productProvider = context.read<ProductProvider>();
      final categories = productProvider.categories;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select categories'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: categories
                    .map(
                      (c) => CheckboxListTile(
                        value: selectedCategoryIds.contains(c.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selectedCategoryIds.add(c.id);
                            } else {
                              selectedCategoryIds.remove(c.id);
                            }
                          });
                        },
                        title: Text(c.name),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingLg,
                right: AppTheme.spacingLg,
                top: AppTheme.spacingLg,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    AppTheme.spacingLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Coupon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Code (e.g., SAVE10)'),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  DropdownButtonFormField<String>(
                    value: discountType,
                    decoration: const InputDecoration(labelText: 'Discount Type'),
                    items: const [
                      DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
                      DropdownMenuItem(value: 'FIXED', child: Text('Fixed Amount')),
                    ],
                    onChanged: (v) => setState(() => discountType = v ?? 'PERCENT'),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: discountType == 'PERCENT' ? 'Percent (1-100)' : 'Amount',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min eligible amount (optional)'),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await pickProducts();
                            if (mounted) setState(() {});
                          },
                          child: Text(
                            selectedProductIds.isEmpty
                                ? 'Select products'
                                : 'Products (${selectedProductIds.length})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await pickCategories();
                            if (mounted) setState(() {});
                          },
                          child: Text(
                            selectedCategoryIds.isEmpty
                                ? 'Select categories'
                                : 'Categories (${selectedCategoryIds.length})',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Consumer<VendorProvider>(
                    builder: (context, vendor, _) {
                      return CustomButton(
                        text: 'Create',
                        isLoading: vendor.isLoading,
                        onPressed: () async {
                          final code = codeController.text.trim();
                          final value = double.tryParse(valueController.text.trim());
                          final min = minController.text.trim().isEmpty
                              ? null
                              : double.tryParse(minController.text.trim());

                          if (code.isEmpty || value == null || value <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid code and discount.')),
                            );
                            return;
                          }

                          final ok = await vendor.createCoupon(
                            code: code,
                            discountType: discountType,
                            discountValue: value,
                            minOrderAmount: min,
                            productIds: selectedProductIds.toList(),
                            categoryIds: selectedCategoryIds.toList(),
                          );
                          if (!context.mounted) return;

                          if (ok) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Coupon created'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(vendor.error ?? 'Failed to create coupon'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _couponTile(VendorCouponModel c) {
    final valueLabel = c.discountType == 'PERCENT'
        ? '${c.discountValue.toStringAsFixed(0)}%'
        : '\$${c.discountValue.toStringAsFixed(2)}';
    final minLabel = c.minOrderAmount == null ? null : 'Min: \$${c.minOrderAmount!.toStringAsFixed(2)}';
    final scopeLabelParts = <String>[
      valueLabel,
      if (minLabel != null) minLabel,
      if (c.productIds.isNotEmpty) 'Products: ${c.productIds.length}',
      if (c.categoryIds.isNotEmpty) 'Categories: ${c.categoryIds.length}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceLight, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (c.isActive ? AppTheme.success : AppTheme.warning)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.discount_outlined,
              color: c.isActive ? AppTheme.success : AppTheme.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scopeLabelParts.join(' • '),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            c.isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: c.isActive ? AppTheme.success : AppTheme.warning,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Coupons',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => _showCreateCouponSheet(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Create Coupon',
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Expanded(
              child: Consumer<VendorProvider>(
                builder: (context, vendor, _) {
                  if (vendor.isLoading && vendor.coupons.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  if (vendor.error != null && vendor.coupons.isEmpty) {
                    return Center(
                      child: Text(
                        vendor.error!,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  if (vendor.coupons.isEmpty) {
                    return const Center(
                      child: Text(
                        'No coupons yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () => vendor.loadCoupons(),
                    child: ListView.builder(
                      itemCount: vendor.coupons.length,
                      itemBuilder: (context, index) =>
                          _couponTile(vendor.coupons[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
