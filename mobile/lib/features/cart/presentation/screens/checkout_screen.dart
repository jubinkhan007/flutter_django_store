import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../../orders/presentation/screens/order_confirmation_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import '../widgets/checkout_step_indicator.dart';
import '../widgets/checkout_address_step.dart';
import '../widgets/checkout_payment_step.dart';
import '../widgets/checkout_review_step.dart';

/// Full-screen checkout with 3-step stepper layout.
class CheckoutScreen extends StatelessWidget {
  final VoidCallback? onOrderPlaced;

  const CheckoutScreen({super.key, this.onOrderPlaced});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CheckoutProvider(
        orderRepository: context.read<OrderRepository>(),
        cartProvider: context.read<CartProvider>(),
      ),
      child: _CheckoutScreenContent(onOrderPlaced: onOrderPlaced),
    );
  }
}

class _CheckoutScreenContent extends StatelessWidget {
  final VoidCallback? onOrderPlaced;
  const _CheckoutScreenContent({this.onOrderPlaced});

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return PopScope(
      canPop: checkout.currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          checkout.previousStep();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: AppColors.lightSurface,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              if (checkout.currentStep > 0) {
                checkout.previousStep();
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            'Checkout',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Step indicator
            Container(
              color: AppColors.lightSurface,
              child: CheckoutStepIndicator(currentStep: checkout.currentStep),
            ),
            const Divider(height: 1, color: AppColors.lightOutline),

            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _buildStepContent(checkout.currentStep),
              ),
            ),

            // Bottom action bar
            _BottomActionBar(
              checkout: checkout,
              primaryColor: primaryColor,
              onOrderPlaced: onOrderPlaced,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const CheckoutAddressStep(key: ValueKey('address'));
      case 1:
        return const CheckoutPaymentStep(key: ValueKey('payment'));
      case 2:
        return const CheckoutReviewStep(key: ValueKey('review'));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BottomActionBar extends StatelessWidget {
  final CheckoutProvider checkout;
  final Color primaryColor;
  final VoidCallback? onOrderPlaced;

  const _BottomActionBar({
    required this.checkout,
    required this.primaryColor,
    this.onOrderPlaced,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = checkout.currentStep == 2;
    final canProceed = checkout.canAdvance(checkout.currentStep);
    final isLoading = checkout.isPlacingOrder;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: AppColors.lightOutline, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (checkout.currentStep > 0)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: PrimaryButton(
                    text: 'Back',
                    outlined: true,
                    onPressed: () => checkout.previousStep(),
                  ),
                ),
              ),
            Expanded(
              flex: checkout.currentStep > 0 ? 2 : 1,
              child: PrimaryButton(
                text: isLastStep ? 'Place Order' : 'Continue',
                isLoading: isLoading,
                onPressed: canProceed
                    ? () => _handleAction(context, checkout)
                    : () => _showValidationError(context, checkout),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    CheckoutProvider checkout,
  ) async {
    if (checkout.currentStep < 2) {
      checkout.nextStep();
    } else {
      // Place order
      final success = await checkout.placeOrder();
      if (success && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(
              order: checkout.placedOrder!,
              paymentMethod: checkout.paymentMethod,
              orderRepository: context.read<OrderRepository>(),
              onViewOrders: onOrderPlaced,
            ),
          ),
        );
      }
    }
  }

  void _showValidationError(BuildContext context, CheckoutProvider checkout) {
    String message;
    switch (checkout.currentStep) {
      case 0:
        message = 'Please select a delivery address';
        break;
      case 1:
        message = 'Please select a payment method';
        break;
      case 2:
        message = checkout.quote?.hasStockWarnings == true
            ? 'Please resolve stock issues before ordering'
            : 'Quote validation required';
        break;
      default:
        message = 'Please complete this step';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.warning,
      ),
    );
  }
}
