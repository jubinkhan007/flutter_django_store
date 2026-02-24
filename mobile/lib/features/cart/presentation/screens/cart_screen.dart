import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/cart_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../addresses/data/models/address_model.dart';
import '../../../addresses/presentation/screens/address_management_screen.dart';
import '../../../orders/presentation/screens/order_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<String?> _selectPaymentMethod(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        var selected = 'ONLINE';
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLg,
                AppTheme.spacingLg,
                AppTheme.spacingLg,
                AppTheme.spacingLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose payment method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  RadioListTile<String>(
                    value: 'ONLINE',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v ?? 'ONLINE'),
                    title: const Text('Pay online'),
                    subtitle: const Text('SSLCommerz payment gateway'),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    value: 'COD',
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v ?? 'COD'),
                    title: const Text('Cash on delivery'),
                    subtitle: const Text('Pay when your order arrives'),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  CustomButton(
                    text: 'Continue',
                    onPressed: () => Navigator.pop(context, selected),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCheckout(
    BuildContext context,
    CartProvider cart,
    OrderProvider orderProvider,
  ) async {
    // 1. Select Delivery Address
    final selectedAddress = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressManagementScreen(isSelectionMode: true),
      ),
    );

    if (selectedAddress == null || !context.mounted) return;

    // 2. Choose payment method
    final paymentMethod = await _selectPaymentMethod(context);
    if (paymentMethod == null || !context.mounted) return;

    final order = await orderProvider.placeOrder(
      cart.toOrderItems(),
      selectedAddress.id,
      paymentMethod: paymentMethod,
    );

    if (order != null && context.mounted) {
      // Clear cart
      cart.clear();

      if (paymentMethod == 'COD') {
        // Show a confirmation dialog for COD
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                  SizedBox(width: 8),
                  Text('Order Placed!'),
                ],
              ),
              content: Text(
                'Order #${order.id} has been placed successfully.\nPayment: Cash on Delivery',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('View Orders'),
                ),
              ],
            ),
          );
          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            );
          }
        }
      } else {
        // Initiate SSLCommerz Payment
        final paymentUrl = await orderProvider.initiatePayment(order.id);

        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                  SizedBox(width: 8),
                  Text('Order Placed!'),
                ],
              ),
              content: Text(
                'Order #${order.id} created.\nYou will now be redirected to the payment gateway.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Proceed to Payment'),
                ),
              ],
            ),
          );
        }

        if (paymentUrl != null && context.mounted) {
          final uri = Uri.parse(paymentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch payment gateway')),
            );
          }
        }

        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
          );
        }
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.error ?? 'Order failed'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<CartProvider>(
        builder: (context, cart, _) {
          return Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Cart',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!cart.isEmpty)
                      TextButton(
                        onPressed: () => cart.clear(),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: AppTheme.error),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Cart Items or Empty State ──
              Expanded(
                child: cart.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              color: AppTheme.textSecondary,
                              size: 64,
                            ),
                            SizedBox(height: AppTheme.spacingMd),
                            Text(
                              'Your cart is empty',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: AppTheme.spacingSm),
                            Text(
                              'Browse products and add items',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMd,
                        ),
                        itemCount: cart.items.length,
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return Dismissible(
                            key: ValueKey(item.product.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) =>
                                cart.removeFromCart(item.product.id),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(
                                bottom: AppTheme.spacingSm,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.error,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(
                                bottom: AppTheme.spacingSm,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Product Image
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Controls
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => cart.updateQuantity(
                                            item.product.id,
                                            item.quantity - 1,
                                          ),
                                          icon: const Icon(
                                            Icons.remove,
                                            size: 16,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                        Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => cart.updateQuantity(
                                            item.product.id,
                                            item.quantity + 1,
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── Bottom Checkout Bar ──
              if (!cart.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(
                      top: BorderSide(color: AppTheme.surfaceLight, width: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '\$${cart.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      Consumer<OrderProvider>(
                        builder: (context, orderProvider, _) {
                          return CustomButton(
                            text: 'Place Order',
                            isLoading: orderProvider.isLoading,
                            onPressed: () =>
                                _handleCheckout(context, cart, orderProvider),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
