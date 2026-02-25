import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/vendor_provider.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _storeNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleOnboard() async {
    if (!_formKey.currentState!.validate()) return;

    final vendor = context.read<VendorProvider>();
    final authProvider = context.read<AuthProvider>();
    final success = await vendor.onboard(
      _storeNameController.text.trim(),
      _descriptionController.text.trim(),
    );

    if (success && mounted) {
      // Promote local user type so the app shows vendor screens
      await authProvider.updateUserType('VENDOR');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 Store created! Welcome aboard!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      );
      Navigator.pushReplacementNamed(context, '/vendor');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Vendor'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Illustration / Header ──
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppGradients.lightPrimary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Center(
              child: Text(
                'Set Up Your Store',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Center(
              child: Text(
                'Start selling your products to customers worldwide',
                style: TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Form ──
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _storeNameController,
                    hintText: 'e.g., TechWorld Store',
                    labelText: 'Store Name',
                    prefixIcon: Icons.storefront_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your store name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _descriptionController,
                    hintText: 'Tell customers about your store...',
                    labelText: 'Store Description',
                    prefixIcon: Icons.description_outlined,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please describe your store';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Error
            Consumer<VendorProvider>(
              builder: (context, vendor, _) {
                if (vendor.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        vendor.error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Submit
            Consumer<VendorProvider>(
              builder: (context, vendor, _) {
                return PrimaryButton(
                  text: 'Create My Store',
                  isLoading: vendor.isLoading,
                  onPressed: _handleOnboard,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
