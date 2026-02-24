import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/order_model.dart';
import '../providers/order_provider.dart';
import '../../../returns/presentation/screens/return_create_screen.dart';
import '../../../returns/presentation/screens/return_list_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with WidgetsBindingObserver {
  bool _awaitingPaymentReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingPaymentReturn) {
      _awaitingPaymentReturn = false;
      context.read<OrderProvider>().loadOrders();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppTheme.warning;
      case 'PAID':
        return Colors.blue;
      case 'SHIPPED':
        return Colors.cyan;
      case 'DELIVERED':
        return AppTheme.success;
      case 'CANCELED':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
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
        return AppTheme.success;
      case 'REFUNDED':
        return AppTheme.warning;
      case 'UNPAID':
      default:
        return AppTheme.error;
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
        _awaitingPaymentReturn = true;
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
            child: const Text('Yes', style: TextStyle(color: AppTheme.error)),
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
            backgroundColor: AppTheme.success,
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
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReturnListScreen()),
                    );
                  },
                  icon: const Icon(Icons.assignment_return_outlined),
                  tooltip: 'My Returns',
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                if (provider.orders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: AppTheme.textSecondary,
                          size: 64,
                        ),
                        SizedBox(height: AppTheme.spacingMd),
                        Text(
                          'No orders yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => provider.loadOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                    ),
                    itemCount: provider.orders.length,
                    itemBuilder: (context, index) {
                      final order = provider.orders[index];
                      final statusColor = _statusColor(order.status);
                      final paymentColor = _paymentColor(order.paymentStatus);
                      final isCod = order.paymentMethod == 'COD';

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: AppTheme.spacingSm,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
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
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
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
                                              backgroundColor: AppTheme.primary,
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
                                            foregroundColor: AppTheme.error,
                                            side: const BorderSide(
                                              color: AppTheme.error,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (order.status == 'DELIVERED')
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  8,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final submitted = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReturnCreateScreen(order: order),
                                        ),
                                      );
                                      if (submitted == true && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Return request submitted'),
                                            backgroundColor: AppTheme.success,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                                    label: const Text('Return / Replace'),
                                  ),
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
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${order.deliveryAddress!.label} - ${order.deliveryAddress!.phoneNumber}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${order.deliveryAddress!.addressLine}, ${order.deliveryAddress!.area}, ${order.deliveryAddress!.city}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
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
                                            color: AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${item.productName ?? 'Product'} × ${item.quantity}',
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
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
