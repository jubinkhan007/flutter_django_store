import 'package:flutter/material.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/checkout_quote_model.dart';

/// Reusable order summary card showing items and pricing breakdown.
/// Used by both checkout review step and order confirmation screen.
class OrderSummaryCard extends StatelessWidget {
  final CheckoutQuote quote;

  const OrderSummaryCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Item list
          ...quote.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Product image placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      image: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                ApiConfig.resolveUrl(item.imageUrl!),
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: item.imageUrl == null || item.imageUrl!.isEmpty
                        ? const Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                            color: AppColors.lightMuted,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${item.lineTotal.toStringAsFixed(2)}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 24),

          // Pricing breakdown
          _PricingRow(label: 'Subtotal', value: quote.subtotal),
          if (quote.discount > 0) ...[
            _PricingRow(
              label: quote.couponLabel != null
                  ? 'Discount (${quote.couponLabel})'
                  : 'Discount',
              value: -quote.discount,
              valueColor: AppColors.success,
            ),
          ],
          if (quote.shipping > 0)
            _PricingRow(label: 'Shipping', value: quote.shipping),
          if (quote.tax > 0) _PricingRow(label: 'Tax', value: quote.tax),

          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.lightTextPrimary,
                ),
              ),
              Text(
                '\$${quote.total.toStringAsFixed(2)}',
                style: AppTextStyles.titleMedium.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? valueColor;

  const _PricingRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final displayValue = isNegative
        ? '-\$${value.abs().toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          Text(
            displayValue,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.lightTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
