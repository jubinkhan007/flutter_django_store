import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../addresses/data/models/address_model.dart';
import '../../../addresses/presentation/providers/address_provider.dart';
import '../../../addresses/presentation/screens/address_management_screen.dart';
import '../providers/checkout_provider.dart';

/// Step 1: Address selection with saved address cards.
class CheckoutAddressStep extends StatefulWidget {
  const CheckoutAddressStep({super.key});

  @override
  State<CheckoutAddressStep> createState() => _CheckoutAddressStepState();
}

class _CheckoutAddressStepState extends State<CheckoutAddressStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Consumer<AddressProvider>(
      builder: (context, addressProvider, _) {
        if (addressProvider.isLoading) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final addresses = addressProvider.addresses;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Delivery Address',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (addresses.isEmpty)
                _EmptyAddressCard(onAdd: () => _addNewAddress(context)),

              ...addresses.map(
                (addr) => _AddressCard(
                  address: addr,
                  isSelected: checkout.selectedAddress?.id == addr.id,
                  onTap: () => checkout.selectAddress(addr),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              TextButton.icon(
                onPressed: () => _addNewAddress(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Address'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addNewAddress(BuildContext context) async {
    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressManagementScreen(isSelectionMode: true),
      ),
    );
    if (result != null && mounted) {
      context.read<CheckoutProvider>().selectAddress(result);
    }
  }
}

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : AppColors.lightOutline,
                  width: 2,
                ),
                color: isSelected ? primaryColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${address.addressLine}, ${address.area}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${address.city} • ${address.phoneNumber}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.lightMuted,
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
}

class _EmptyAddressCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAddressCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onAdd,
      child: Column(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 48,
            color: AppColors.lightMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No saved addresses',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a delivery address to continue',
            style: AppTextStyles.caption.copyWith(color: AppColors.lightMuted),
          ),
        ],
      ),
    );
  }
}
