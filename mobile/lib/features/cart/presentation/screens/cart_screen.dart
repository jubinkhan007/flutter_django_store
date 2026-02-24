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

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponController = TextEditingController();
  String? _appliedCouponCode;
  double _discountAmount = 0.0;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  void _clearCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _discountAmount = 0.0;
      _couponError = null;
    });
  }

  Future<void> _applyCoupon(CartProvider cart, OrderProvider orderProvider) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    final result = await orderProvider.validateCoupon(code, cart.toOrderItems());
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _appliedCouponCode = null;
        _discountAmount = 0.0;
        _couponError = orderProvider.error ?? 'Invalid coupon';
      });
      return;
    }

    final discount = double.tryParse(result['discount']?.toString() ?? '0') ?? 0.0;
    setState(() {
      _appliedCouponCode = result['code']?.toString() ?? code.toUpperCase();
      _discountAmount = discount;
      _couponError = null;
    });
  }

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
      couponCode: _appliedCouponCode,
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
          final subtotal = cart.totalPrice;
          final total = (subtotal - _discountAmount).clamp(0.0, double.infinity);
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
                      Consumer<OrderProvider>(
                        builder: (context, orderProvider, _) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _couponController,
                                      decoration: InputDecoration(
                                        hintText: 'Coupon code',
                                        isDense: true,
                                        filled: true,
                                        fillColor: AppTheme.surfaceLight,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      textInputAction: TextInputAction.done,
                                      onChanged: (_) {
                                        if (_appliedCouponCode != null) {
                                          _clearCoupon();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 110,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: orderProvider.isLoading
                                          ? null
                                          : () {
                                              if (_appliedCouponCode != null) {
                                                _couponController.clear();
                                                _clearCoupon();
                                                return;
                                              }
                                              _applyCoupon(cart, orderProvider);
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _appliedCouponCode == null
                                            ? AppTheme.primary
                                            : AppTheme.error,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm,
                                          ),
                                        ),
                                      ),
                                      child: orderProvider.isLoading
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _appliedCouponCode == null
                                                  ? 'Apply'
                                                  : 'Remove',
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_couponError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _couponError!,
                                      style: const TextStyle(
                                        color: AppTheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_appliedCouponCode != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Applied: $_appliedCouponCode',
                                      style: const TextStyle(
                                        color: AppTheme.success,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppTheme.spacingMd),
                            ],
                          );
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '\$${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (_discountAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Discount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '-\$${_discountAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
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
                              '\$${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
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
