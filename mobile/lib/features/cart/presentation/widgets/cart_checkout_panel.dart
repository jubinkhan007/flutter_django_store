import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/primary_button.dart';

/// Frosted-glass bottom panel with coupon chip, pricing breakdown,
/// and gradient "Checkout" button.
class CartCheckoutPanel extends StatelessWidget {
  final double subtotal;
  final double couponDiscount;
  final String? couponCode;
  final VoidCallback onCheckout;
  final VoidCallback? onApplyCoupon;
  final VoidCallback? onRemoveCoupon;
  final bool isLoading;

  const CartCheckoutPanel({
    super.key,
    required this.subtotal,
    required this.couponDiscount,
    this.couponCode,
    required this.onCheckout,
    this.onApplyCoupon,
    this.onRemoveCoupon,
    this.isLoading = false,
  });

  double get total => (subtotal - couponDiscount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.lightSurface.withAlpha(240),
            border: const Border(
              top: BorderSide(color: AppColors.lightOutline, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coupon row
                if (couponCode != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.success.withAlpha(64),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              couponCode!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '-\$${couponDiscount.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onRemoveCoupon,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.lightMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ] else if (onApplyCoupon != null) ...[
                  GestureDetector(
                    onTap: onApplyCoupon,
                    child: Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Apply Coupon',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Pricing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      '\$${subtotal.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                      '\$${total.toStringAsFixed(2)}',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                PrimaryButton(
                  text: 'Proceed to Checkout',
                  isLoading: isLoading,
                  onPressed: onCheckout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
