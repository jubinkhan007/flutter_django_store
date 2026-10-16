import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../addresses/presentation/providers/address_provider.dart';
import '../../data/models/delivery_estimate_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/variant.dart';
import '../providers/delivery_estimate_provider.dart';

class DeliveryEstimateCard extends StatelessWidget {
  final Product product;
  final ProductVariant? selectedVariant;

  const DeliveryEstimateCard({
    super.key,
    required this.product,
    this.selectedVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryEstimateProvider>(
      builder: (context, provider, _) {
        final estimate = provider.estimate;
        final isLoading = provider.isLoading;
        final error = provider.errorMessage;

        if (isLoading && estimate == null) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.lightTextSecondary.withAlpha(25),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Estimating delivery dates & shipping fees...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        if (error != null && estimate == null) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Standard delivery available nationwide',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => provider.loadEstimate(
                    product.id,
                    variantId: selectedVariant?.id,
                    force: true,
                  ),
                  child: const Text('Retry', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          );
        }

        if (estimate == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: Theme.of(context).primaryColor.withAlpha(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Destination Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.lightTextSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Deliver to: '),
                            TextSpan(
                              text: estimate.formattedDestination,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showLocationPickerSheet(context, estimate),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.5, color: Colors.black12),

              // ── Shipping Tiers ──
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ...estimate.options.map((option) => _buildOptionRow(context, option)),

                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                    const SizedBox(height: 10),

                    // ── Trust & Policy Badges ──
                    Row(
                      children: [
                        if (estimate.codAvailable) ...[
                          const Icon(
                            Icons.payments_outlined,
                            size: 15,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            estimate.returnPolicyNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionRow(BuildContext context, DeliveryOptionModel option) {
    final isExpress = option.code == 'EXPRESS';
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isExpress
                  ? Colors.amber.withAlpha(30)
                  : primaryColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpress ? Icons.bolt : Icons.local_shipping_outlined,
              size: 14,
              color: isExpress ? Colors.amber.shade800 : primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    if (option.badge.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isExpress
                              ? Colors.amber.shade100
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          option.badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isExpress
                                ? Colors.amber.shade900
                                : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Get it by ${option.estimatedDeliveryDisplay}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            option.isFree ? 'FREE' : option.feeDisplay,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: option.isFree ? AppColors.success : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationPickerSheet(
    BuildContext context,
    DeliveryEstimateModel currentEstimate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _LocationPickerSheet(
        product: product,
        selectedVariant: selectedVariant,
        currentCity: currentEstimate.destinationCity,
        currentArea: currentEstimate.destinationArea,
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final Product product;
  final ProductVariant? selectedVariant;
  final String currentCity;
  final String currentArea;

  const _LocationPickerSheet({
    required this.product,
    this.selectedVariant,
    required this.currentCity,
    required this.currentArea,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const List<String> _districts = [
    'Dhaka',
    'Chittagong',
    'Sylhet',
    'Rajshahi',
    'Khulna',
    'Barisal',
    'Rangpur',
    'Mymensingh',
    'Gazipur',
    'Narayanganj',
    'Comilla',
  ];

  late String _selectedCity;
  late TextEditingController _areaController;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.currentCity.isNotEmpty ? widget.currentCity : 'Dhaka';
    _areaController = TextEditingController(text: widget.currentArea);
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addressProvider = context.watch<AddressProvider>();
    final savedAddresses = addressProvider.addresses;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select Delivery Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Delivery fees and arrival dates will update automatically.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // ── Saved Addresses (if available) ──
          if (savedAddresses.isNotEmpty) ...[
            const Text(
              'Your Saved Addresses',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: savedAddresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final addr = savedAddresses[index];
                  final isSelected = _selectedCity.toLowerCase() == addr.city.toLowerCase() &&
                      _areaController.text.trim().toLowerCase() == addr.area.trim().toLowerCase();

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCity = addr.city;
                        _areaController.text = addr.area;
                      });
                    },
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor.withAlpha(20) : AppColors.lightSurface,
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 16,
                            color: isSelected ? primaryColor : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${addr.label}: ${addr.area}, ${addr.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Quick City Chips ──
          const Text(
            'Select City / District',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _districts.map((city) {
              final isChosen = _selectedCity.toLowerCase() == city.toLowerCase();
              return ChoiceChip(
                label: Text(city),
                selected: isChosen,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                  color: isChosen ? Colors.white : AppColors.lightTextPrimary,
                ),
                selectedColor: primaryColor,
                backgroundColor: AppColors.lightSurface,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCity = city;
                    });
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ── Area / Thana Input ──
          TextField(
            controller: _areaController,
            decoration: InputDecoration(
              labelText: 'Area / Thana (Optional)',
              hintText: 'e.g. Gulshan, Uttara, Mirpur, Agrabad',
              filled: true,
              fillColor: AppColors.lightSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 18),

          // ── Apply Button ──
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: () {
                final area = _areaController.text.trim();
                context.read<DeliveryEstimateProvider>().updateLocation(
                  widget.product.id,
                  city: _selectedCity,
                  area: area.isNotEmpty ? area : null,
                  variantId: widget.selectedVariant?.id,
                );
                Navigator.pop(context);
              },
              child: const Text(
                'Apply Location',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
