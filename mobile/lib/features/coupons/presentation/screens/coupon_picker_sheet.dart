import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../data/models/available_coupon_model.dart';
import '../providers/coupon_provider.dart';

class CouponPickerSheet extends StatefulWidget {
  const CouponPickerSheet({super.key});

  @override
  State<CouponPickerSheet> createState() => _CouponPickerSheetState();
}

class _CouponPickerSheetState extends State<CouponPickerSheet> {
  late Future<List<AvailableCouponModel>> _future;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _future = context.read<CouponProvider>().fetchAvailableCoupons(
      items: cart.toOrderItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select a coupon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                if (cart.couponCode != null)
                  TextButton(
                    onPressed: () {
                      cart.clearCoupon();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Subtotal: \$${cart.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.lightTextSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<AvailableCouponModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  final msg = snapshot.error.toString().replaceAll(
                    'Exception: ',
                    '',
                  );
                  return _ErrorState(
                    message: msg,
                    onRetry: () {
                      setState(() {
                        _future = context
                            .read<CouponProvider>()
                            .fetchAvailableCoupons(items: cart.toOrderItems());
                      });
                    },
                  );
                }

                final coupons = snapshot.data ?? const [];
                if (coupons.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        'No coupons available for this cart',
                        style: TextStyle(color: AppColors.lightTextSecondary),
                      ),
                    ),
                  );
                }

                return Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: coupons.length,
                    itemBuilder: (context, index) {
                      final c = coupons[index];
                      final scoped = c.scope == 'GLOBAL'
                          ? 'All shops'
                          : (c.vendorName?.isNotEmpty == true
                                ? c.vendorName!
                                : 'Shop ${c.vendorId ?? ''}');
                      final label = c.discountType == 'PERCENT'
                          ? '${c.discountValue.toStringAsFixed(0)}% off'
                          : '\$${c.discountValue.toStringAsFixed(2)} off';
                      final minText = c.minOrderAmount == null
                          ? null
                          : 'Min \$${c.minOrderAmount!.toStringAsFixed(2)} eligible';

                      final isApplied = cart.couponCode == c.code;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isApplied
                                ? AppColors.success.withAlpha(
                                    (0.4 * 255).round(),
                                  )
                                : AppColors.lightSurface,
                            width: 0.6,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            cart.applyCoupon(
                              code: c.code,
                              discountAmount: c.discount,
                            );
                            Navigator.pop(context);
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor
                                      .withAlpha((0.15 * 255).round()),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.confirmation_number_outlined,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.code,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '-\$${c.discount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$label • $scoped${minText == null ? '' : ' • $minText'}',
                                      style: TextStyle(
                                        color: AppColors.lightTextSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Eligible subtotal: \$${c.eligibleSubtotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: AppColors.lightTextSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isApplied) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(color: AppColors.lightTextSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
