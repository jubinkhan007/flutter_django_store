import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/order_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            child: Text(
              'My Orders',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // ── Order List ──
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
                        SizedBox(height: AppTheme.spacingSm),
                        Text(
                          'Your order history will appear here',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
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
                            // Order Header
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
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${order.items.length} item(s)',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
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

                            // Order Items
                            if (order.items.isNotEmpty)
                              Container(
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
