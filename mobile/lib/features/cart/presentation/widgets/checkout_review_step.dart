import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../orders/data/models/checkout_quote_model.dart';
import '../../../orders/presentation/widgets/order_summary_card.dart';
import '../providers/checkout_provider.dart';

/// Step 3: Server-validated quote review with pricing breakdown.
class CheckoutReviewStep extends StatelessWidget {
  const CheckoutReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    if (checkout.isFetchingQuote) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Validating your order...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (checkout.error != null && checkout.quote == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              checkout.error!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () => checkout.fetchQuote(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final quote = checkout.quote;
    if (quote == null) {
      return const Center(child: Text('No quote data available.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Stock warnings
          if (quote.hasStockWarnings) ...[
            _StockWarningBanner(warnings: quote.stockWarnings),
            const SizedBox(height: AppSpacing.md),
          ],

          // Order summary card
          OrderSummaryCard(quote: quote),

          const SizedBox(height: AppSpacing.md),

          // Delivery info
          AppCard(
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkout.selectedAddress?.label ?? 'Delivery Address',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        '${checkout.selectedAddress?.addressLine ?? ''}, ${checkout.selectedAddress?.city ?? ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Payment info
          AppCard(
            child: Row(
              children: [
                Icon(
                  checkout.paymentMethod == 'COD'
                      ? Icons.local_shipping_outlined
                      : Icons.credit_card_rounded,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  checkout.paymentMethod == 'COD'
                      ? 'Cash on Delivery'
                      : 'Pay Online (SSLCommerz)',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),

          if (checkout.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      checkout.error!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockWarningBanner extends StatelessWidget {
  final List<StockWarning> warnings;

  const _StockWarningBanner({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withAlpha(64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Stock Availability Issues',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${w.productName}: requested ${w.requested}, only ${w.available} available',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
