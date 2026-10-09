import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/checkout_provider.dart';

/// Step 2: Payment method selection with radio tiles and wallet payment toggle.
class CheckoutPaymentStep extends StatelessWidget {
  const CheckoutPaymentStep({super.key});

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final auth = context.watch<AuthProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    final walletBalance = (checkout.quote?.userWalletBalance != null &&
            (checkout.quote?.userWalletBalance ?? 0.0) > 0)
        ? checkout.quote!.userWalletBalance
        : (auth.user?.walletBalance ?? 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Wallet Payment Option ──
          if (auth.isLoggedIn && walletBalance > 0) ...[
            Text(
              'Wallet Payment',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Wallet Balance',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Available: \$${walletBalance.toStringAsFixed(2)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: checkout.useWallet,
                        activeTrackColor: primaryColor,
                        onChanged: (val) => checkout.toggleUseWallet(val),
                      ),
                    ],
                  ),
                  if (checkout.useWallet) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Wallet funds will be applied up to the order total. Any remaining balance will be split with your chosen payment method below.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          Text(
            checkout.useWallet
                ? 'Payment Method (for remaining balance)'
                : 'Payment Method',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _PaymentOptionCard(
            icon: Icons.credit_card_rounded,
            title: 'Pay Online',
            subtitle: checkout.useWallet
                ? 'Pay remaining balance via SSLCommerz gateway'
                : 'SSLCommerz secure payment gateway',
            value: 'ONLINE',
            groupValue: checkout.paymentMethod,
            primaryColor: primaryColor,
            onTap: () => checkout.selectPaymentMethod('ONLINE'),
          ),
          const SizedBox(height: AppSpacing.sm),

          _PaymentOptionCard(
            icon: Icons.local_shipping_outlined,
            title: 'Cash on Delivery',
            subtitle: checkout.useWallet
                ? 'Pay remaining balance when order arrives'
                : 'Pay when your order arrives',
            value: 'COD',
            groupValue: checkout.paymentMethod,
            primaryColor: primaryColor,
            onTap: () => checkout.selectPaymentMethod('COD'),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withAlpha(25)
                  : AppColors.lightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected ? primaryColor : AppColors.lightTextSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
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
        ],
      ),
    );
  }
}
