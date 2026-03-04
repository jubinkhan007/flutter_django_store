import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadOnboardingProgress();
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateStore() async {
    if (!_formKey.currentState!.validate()) return;
    final vendor = context.read<VendorProvider>();
    final success = await vendor.onboard(
      _storeNameController.text.trim(),
      _descriptionController.text.trim(),
    );

    if (success && mounted) {
      context.read<AuthProvider>().updateUserType('VENDOR');
      await vendor.loadOnboardingProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Setup Wizard'),
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: Consumer<VendorProvider>(
        builder: (context, vendor, _) {
          final progress = vendor.onboardingProgress;
          if (progress == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final storeCreated = progress['store_created'] == true;
          final payoutAdded = progress['payout_method_added'] == true;
          final pickupLinked = progress['pickup_store_linked'] == true;
          final productAdded = progress['first_product_with_variant'] == true;
          final isReady = progress['is_ready'] == true;

          // Auto-advance step logic based on completion
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            int targetStep = 0;
            if (storeCreated) targetStep = 1;
            if (storeCreated && payoutAdded) targetStep = 2;
            if (storeCreated && payoutAdded && pickupLinked) targetStep = 3;
            if (storeCreated && payoutAdded && pickupLinked && productAdded)
              targetStep = 4;

            if (_currentStep != targetStep && targetStep < 4) {
              setState(() => _currentStep = targetStep);
            }
          });

          if (isReady) {
            return _buildSuccessView();
          }

          return Stepper(
            currentStep: _currentStep,
            onStepTapped: (index) {
              // Only allow tapping previous completed steps
              if (index <= _currentStep) {
                setState(() => _currentStep = index);
              }
            },
            controlsBuilder: (context, details) {
              return const SizedBox.shrink(); // Hide default continue/cancel buttons
            },
            steps: [
              Step(
                title: const Text('Create Store Profile'),
                subtitle: const Text('Name and description'),
                isActive: _currentStep >= 0,
                state: storeCreated ? StepState.complete : StepState.editing,
                content: storeCreated
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '✅ Store created successfully.',
                          style: TextStyle(color: AppColors.success),
                        ),
                      )
                    : _buildStoreForm(vendor),
              ),
              Step(
                title: const Text('Setup Payout Method'),
                subtitle: const Text('Add bank details'),
                isActive: _currentStep >= 1,
                state: payoutAdded ? StepState.complete : StepState.indexed,
                content: _buildActionContent(
                  isCompleted: payoutAdded,
                  completedText: '✅ Payout method is setup.',
                  actionText: 'Go to Wallet to add details',
                  onAction: () async {
                    await Navigator.pushNamed(context, '/vendor/wallet');
                    vendor.loadOnboardingProgress();
                  },
                ),
              ),
              Step(
                title: const Text('Add Pickup Location'),
                subtitle: const Text('Logistics / Warehouse'),
                isActive: _currentStep >= 2,
                state: pickupLinked ? StepState.complete : StepState.indexed,
                content: _buildActionContent(
                  isCompleted: pickupLinked,
                  completedText: '✅ Pickup location linked.',
                  actionText: 'Contact Support to map warehouse',
                  onAction: () {
                    // Placeholder for logistics self-service
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Feature coming soon. Please contact vendor support.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              Step(
                title: const Text('Create First Product'),
                subtitle: const Text('Upload a product with variants'),
                isActive: _currentStep >= 3,
                state: productAdded ? StepState.complete : StepState.indexed,
                content: _buildActionContent(
                  isCompleted: productAdded,
                  completedText: '✅ First product added.',
                  actionText: 'Go to Product Catalog',
                  onAction: () async {
                    await Navigator.pushNamed(context, '/vendor/add-product');
                    vendor.loadOnboardingProgress();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreForm(VendorProvider vendor) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _storeNameController,
            hintText: 'e.g., TechWorld Store',
            labelText: 'Store Name',
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter name' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _descriptionController,
            hintText: 'Tell customers about your store...',
            labelText: 'Description',
            maxLines: 2,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Please enter description' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (vendor.error != null) ...[
            Text(vendor.error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
          ],
          PrimaryButton(
            text: 'Save Store',
            isLoading: vendor.isLoading,
            onPressed: _handleCreateStore,
          ),
        ],
      ),
    );
  }

  Widget _buildActionContent({
    required bool isCompleted,
    required String completedText,
    required String actionText,
    required VoidCallback onAction,
  }) {
    if (isCompleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          completedText,
          style: const TextStyle(color: AppColors.success),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: OutlinedButton(onPressed: onAction, child: Text(actionText)),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'You are all set!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Your store onboarding is complete. Your products can now go live!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.lightTextSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: 'Go to Dashboard',
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/vendor');
              },
            ),
          ],
        ),
      ),
    );
  }
}
