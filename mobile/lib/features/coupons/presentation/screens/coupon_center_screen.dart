import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../providers/coupon_provider.dart';

class CouponCenterScreen extends StatefulWidget {
  const CouponCenterScreen({super.key});

  @override
  State<CouponCenterScreen> createState() => _CouponCenterScreenState();
}

class _CouponCenterScreenState extends State<CouponCenterScreen> {
  final _codeController = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CouponProvider>().loadGlobalCoupons();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCurrentCode() async {
    final cart = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();
    final code = _codeController.text.trim();

    if (code.isEmpty) return;
    if (cart.isEmpty) {
      setState(
        () => _localError = 'Add items to your cart before applying a coupon.',
      );
      return;
    }

    final result = await orderProvider.validateCoupon(code, cart.toOrderItems());
    if (!mounted) return;

    if (result == null) {
      setState(() => _localError = orderProvider.error ?? 'Invalid coupon');
      return;
    }

    final discount =
        double.tryParse(result['discount']?.toString() ?? '0') ?? 0.0;
    cart.applyCoupon(
      code: (result['code']?.toString() ?? code.toUpperCase()),
      discountAmount: discount,
    );
    setState(() => _localError = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied coupon: ${cart.couponCode}'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<CartProvider>(
              builder: (context, cart, _) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cart.isEmpty
                            ? 'Cart is empty'
                            : 'Subtotal: \$${cart.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cart.couponCode == null
                            ? 'No coupon applied'
                            : 'Applied: ${cart.couponCode} (-\$${cart.couponDiscount.toStringAsFixed(2)})',
                        style: TextStyle(
                          color: cart.couponCode == null
                              ? AppTheme.textSecondary
                              : AppTheme.success,
                          fontSize: 12,
                        ),
                      ),
                      if (cart.couponCode != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => cart.clearCoupon(),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Remove coupon'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter coupon code',
                      hintText: 'e.g. SAVE10',
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _applyCurrentCode(),
                  ),
                ),
                const SizedBox(width: 10),
                Consumer<OrderProvider>(
                  builder: (context, orderProvider, _) {
                    return SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: orderProvider.isLoading
                            ? null
                            : _applyCurrentCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                        ),
                        child: orderProvider.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Apply'),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (_localError != null) ...[
              const SizedBox(height: 8),
              Text(
                _localError!,
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),
            const Text(
              'Available coupons',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Consumer<CouponProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.globalCoupons.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }
                  if (provider.error != null &&
                      provider.globalCoupons.isEmpty) {
                    return Center(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  if (provider.globalCoupons.isEmpty) {
                    return const Center(
                      child: Text(
                        'No coupons available',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () => provider.loadGlobalCoupons(),
                    child: ListView.builder(
                      itemCount: provider.globalCoupons.length,
                      itemBuilder: (context, index) {
                        final c = provider.globalCoupons[index];
                        final label = c.discountType == 'PERCENT'
                            ? '${c.discountValue.toStringAsFixed(0)}% off'
                            : '\$${c.discountValue.toStringAsFixed(2)} off';
                        final minText = c.minOrderAmount == null
                            ? null
                            : 'Min \$${c.minOrderAmount!.toStringAsFixed(2)}';
                        final scoped = c.scope == 'GLOBAL'
                            ? 'All shops'
                            : (c.vendorName?.isNotEmpty == true
                                  ? c.vendorName!
                                  : 'Single shop');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.local_offer_outlined,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$label • $scoped${minText == null ? '' : ' • $minText'}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'copy') {
                                    await Clipboard.setData(
                                      ClipboardData(text: c.code),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied coupon code'),
                                      ),
                                    );
                                  }
                                  if (v == 'apply') {
                                    _codeController.text = c.code;
                                    await _applyCurrentCode();
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Text('Copy code'),
                                  ),
                                  PopupMenuItem(
                                    value: 'apply',
                                    child: Text('Apply to cart'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
