import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../orders/data/models/order_model.dart';
import 'return_create_screen.dart';

class ReturnSelectOrderScreen extends StatefulWidget {
  const ReturnSelectOrderScreen({super.key});

  @override
  State<ReturnSelectOrderScreen> createState() =>
      _ReturnSelectOrderScreenState();
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
          final delivered = provider.orders
              .where((o) => o.status == 'DELIVERED')
              .toList();

          if (provider.isLoading && provider.orders.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }

          if (provider.error != null && provider.orders.isEmpty) {
            return Center(
              child: Text(
                provider.error!,
                style: TextStyle(color: AppColors.lightTextSecondary),
              ),
            );
          }

          if (delivered.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No delivered orders available for return.',
                  style: TextStyle(color: AppColors.lightTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: Theme.of(context).primaryColor,
            onRefresh: () => provider.loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
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
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).primaryColor.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: Theme.of(context).primaryColor,
              ),
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
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.items.length} item(s) • \$${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.lightTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
