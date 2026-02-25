import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../data/models/order_model.dart';
import '../providers/order_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with WidgetsBindingObserver {
  Timer? _paymentRefreshTimer;
  bool _paymentRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<OrderProvider>().loadOrders();
      if (!mounted) return;
      _startPaymentPolling();
    });
  }

  @override
  void dispose() {
    _paymentRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _stopPaymentPolling() {
    if (mounted) {
      context.read<OrderProvider>().clearPendingPaymentOrder();
    }
    _paymentRefreshTimer?.cancel();
    _paymentRefreshTimer = null;
    _paymentRefreshInFlight = false;
  }

  void _startPaymentPolling() {
    final orderId = context.read<OrderProvider>().pendingPaymentOrderId;
    if (orderId == null) return;

    _paymentRefreshTimer?.cancel();
    _paymentRefreshInFlight = false;
    var attempts = 0;

    _paymentRefreshTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }

      attempts += 1;
      if (attempts > 30) {
        _stopPaymentPolling();
        return;
      }

      if (_paymentRefreshInFlight) return;
      _paymentRefreshInFlight = true;
      final provider = context.read<OrderProvider>();
      await provider.loadOrdersWithLoading(showLoading: false);
      _paymentRefreshInFlight = false;

      OrderModel? updated;
      for (final o in provider.orders) {
        if (o.id == orderId) {
          updated = o;
          break;
        }
      }

      if (updated == null) {
        _stopPaymentPolling();
        return;
      }

      if (updated.paymentStatus != 'UNPAID') {
        _stopPaymentPolling();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<OrderProvider>().loadOrdersWithLoading(showLoading: false);
      _startPaymentPolling();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'PAID':
        return Colors.blue;
      case 'SHIPPED':
        return Colors.cyan;
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELED':
        return AppColors.error;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'PAID':
        return Icons.payment;
      case 'SHIPPED':
        return Icons.local_shipping_outlined;
      case 'DELIVERED':
        return Icons.check_circle_outline;
      case 'CANCELED':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'PAID':
        return AppColors.success;
      case 'REFUNDED':
        return AppColors.warning;
      case 'UNPAID':
      default:
        return AppColors.error;
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'COD':
        return 'Cash on Delivery';
      case 'ONLINE':
      default:
        return 'Online Payment';
    }
  }

  Future<void> _payNow(BuildContext context, OrderModel order) async {
    final provider = context.read<OrderProvider>();
    final url = await provider.initiatePayment(order.id);
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        provider.setPendingPaymentOrder(order.id);
        _startPaymentPolling();
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _cancelOrder(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<OrderProvider>().cancelOrder(order.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const AppLoadingState(message: 'Loading orders...');
                }

                if (provider.orders.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message: 'When you place an order, it will appear here.',
                  );
                }

                return RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () => provider.loadOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: provider.orders.length,
                    itemBuilder: (context, index) {
                      final order = provider.orders[index];
                      final statusColor = _statusColor(order.status);
                      final paymentColor = _paymentColor(order.paymentStatus);
                      final isCod = order.paymentMethod == 'COD';

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(
                                        38,
                                      ), // 0.15 * 255 = 38.25
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                    ),
                                    child: Icon(
                                      _statusIcon(order.status),
                                      color: statusColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order #${order.id}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${order.items.length} item(s) • ${_paymentMethodLabel(order.paymentMethod)} • ${order.paymentStatus}',
                                          style: TextStyle(
                                            color: paymentColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${order.totalAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          order.status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (order.status == 'PENDING' ||
                                (order.paymentStatus == 'UNPAID' &&
                                    order.status != 'CANCELED'))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Row(
                                  children: [
                                    if (!isCod &&
                                        order.paymentStatus == 'UNPAID' &&
                                        order.status != 'CANCELED')
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _payNow(context, order),
                                            icon: const Icon(
                                              Icons.payment,
                                              size: 16,
                                            ),
                                            label: const Text('Pay Now'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                context,
                                              ).primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (order.status == 'PENDING')
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _cancelOrder(context, order),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          label: const Text('Cancel'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(
                                              color: AppColors.error,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (order.deliveryAddress != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Delivery Address:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${order.deliveryAddress!.label} - ${order.deliveryAddress!.phoneNumber}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${order.deliveryAddress!.addressLine}, ${order.deliveryAddress!.area}, ${order.deliveryAddress!.city}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            if (order.items.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  children: order.items.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: AppColors.lightTextSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${item.productName ?? 'Product'} × ${item.quantity}',
                                              style: const TextStyle(
                                                color: AppColors
                                                    .lightTextSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color:
                                                  AppColors.lightTextSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
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
    );
  }
}
