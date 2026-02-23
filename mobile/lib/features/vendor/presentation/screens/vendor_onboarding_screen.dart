import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
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
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Illustration / Header ──
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            const Center(
              child: Text(
                'Set Up Your Store',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            const Center(
              child: Text(
                'Start selling your products to customers worldwide',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // ── Form ──
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
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
                  const SizedBox(height: AppTheme.spacingMd),
                  CustomTextField(
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
            const SizedBox(height: AppTheme.spacingLg),

            // Error
            Consumer<VendorProvider>(
              builder: (context, vendor, _) {
                if (vendor.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        vendor.error!,
                        style: const TextStyle(
                          color: AppTheme.error,
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
                return CustomButton(
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
