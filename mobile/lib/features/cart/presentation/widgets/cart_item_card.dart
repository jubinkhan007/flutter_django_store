import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/cart_provider.dart';

/// A single cart item card with product image, details, quantity controls,
/// and swipe-to-delete with animated red background.
class CartItemCard extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Dismissible(
      key: ValueKey('${item.product.id}-${item.variant?.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(25),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.error,
          size: 28,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: 72,
                  height: 72,
                  color: AppColors.lightBg,
                  child: item.product.image != null
                      ? Image.network(
                          item.product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_outlined,
                            color: AppColors.lightMuted,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: AppColors.lightMuted,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.lightTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.variant != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Variant #${item.variant!.id}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.lightMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.effectivePrice.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity controls
              Column(
                children: [
                  _QuantityButton(
                    icon: Icons.add,
                    onPressed: () => onQuantityChanged(item.quantity + 1),
                    primaryColor: primaryColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${item.quantity}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.remove,
                    onPressed: item.quantity > 1
                        ? () => onQuantityChanged(item.quantity - 1)
                        : onRemove,
                    primaryColor: item.quantity > 1
                        ? primaryColor
                        : AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color primaryColor;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: primaryColor.withAlpha(64)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: primaryColor),
      ),
    );
  }
}
