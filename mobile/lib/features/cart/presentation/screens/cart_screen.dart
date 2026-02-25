import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../coupons/presentation/screens/coupon_picker_sheet.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/cart_checkout_panel.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        title: Text(
          'Cart',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearCart(context, cart),
              child: Text(
                'Clear',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Browse products and add items to your cart',
            )
          : Stack(
              children: [
                // Item list
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    220, // Space for bottom panel
                  ),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return CartItemCard(
                      item: item,
                      onQuantityChanged: (qty) => cart.updateQuantity(
                        item.product.id,
                        qty,
                        variantId: item.variant?.id,
                      ),
                      onRemove: () => cart.removeFromCart(
                        item.product.id,
                        variantId: item.variant?.id,
                      ),
                    );
                  },
                ),

                // Bottom checkout panel
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CartCheckoutPanel(
                    subtotal: cart.totalPrice,
                    couponDiscount: cart.couponDiscount,
                    couponCode: cart.couponCode,
                    onCheckout: () => _navigateToCheckout(context),
                    onApplyCoupon: () => _showCouponPicker(context, cart),
                    onRemoveCoupon: () => cart.clearCoupon(),
                  ),
                ),
              ],
            ),
    );
  }

  void _navigateToCheckout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  void _showCouponPicker(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CouponPickerSheet(),
    );
  }

  void _confirmClearCart(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text('This will remove all items from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.pop(ctx);
            },
            child: Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
