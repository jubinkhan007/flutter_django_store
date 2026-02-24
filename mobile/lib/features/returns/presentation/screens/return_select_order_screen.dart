import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../orders/data/models/order_model.dart';
import 'return_create_screen.dart';


class ReturnSelectOrderScreen extends StatefulWidget {
  const ReturnSelectOrderScreen({super.key});

  @override
  State<ReturnSelectOrderScreen> createState() => _ReturnSelectOrderScreenState();
}

class _ReturnSelectOrderScreenState extends State<ReturnSelectOrderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OrderProvider>();
      if (provider.orders.isEmpty && !provider.isLoading) {
        provider.loadOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select order')),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          final delivered = provider.orders.where((o) => o.status == 'DELIVERED').toList();

          if (provider.isLoading && provider.orders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (provider.error != null && provider.orders.isEmpty) {
            return Center(
              child: Text(
                provider.error!,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          if (delivered.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                child: Text(
                  'No delivered orders available for return.',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () => provider.loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: delivered.length,
              itemBuilder: (context, index) {
                final order = delivered[index];
                return _OrderTile(
                  order: order,
                  onTap: () async {
                    final submitted = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReturnCreateScreen(order: order),
                      ),
                    );
                    if (submitted == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.items.length} item(s) • \$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

