import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../data/models/cb_models.dart';
import '../providers/crossborder_provider.dart';
import 'cb_order_tracking_screen.dart';

class CbMyOrdersScreen extends StatefulWidget {
  const CbMyOrdersScreen({super.key});

  @override
  State<CbMyOrdersScreen> createState() => _CbMyOrdersScreenState();
}

class _CbMyOrdersScreenState extends State<CbMyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CrossBorderProvider>().loadMyRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My International Orders')),
      body: Consumer<CrossBorderProvider>(
        builder: (context, provider, _) {
          if (provider.requestsLoading && provider.myRequests.isEmpty) {
            return const AppLoadingState(message: 'Loading orders...');
          }
          if (provider.requestsError != null && provider.myRequests.isEmpty) {
            return AppErrorState(
              title: 'Error',
              message: provider.requestsError!,
              onRetry: () => provider.loadMyRequests(),
            );
          }
          if (provider.myRequests.isEmpty) {
            return const AppEmptyState(
              icon: Icons.flight_takeoff,
              title: 'No international orders',
              message: 'Orders you place via the cross-border catalog or Buy by Link will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadMyRequests(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: provider.myRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final req = provider.myRequests[index];
                return _CbOrderTile(
                  request: req,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CbOrderTrackingScreen(requestId: req.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CbOrderTile extends StatelessWidget {
  final CrossBorderOrderRequest request;
  final VoidCallback onTap;

  const _CbOrderTile({required this.request, required this.onTap});

  static Color _statusColor(String s) {
    switch (s) {
      case 'PAYMENT_RECEIVED':
      case 'ORDERED':
        return AppColors.lightPrimary;
      case 'SHIPPED_INTL':
      case 'IN_TRANSIT':
        return Colors.blue;
      case 'OUT_FOR_DELIVERY':
        return Colors.orange;
      case 'DELIVERED':
        return AppColors.success;
      case 'CUSTOMS_HELD':
        return AppColors.warning;
      case 'CANCELLED':
      case 'REFUND_IN_PROGRESS':
        return AppColors.error;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    final statusLabel = request.status.replaceAll('_', ' ');

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Type icon ──
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  request.requestType == 'LINK_PURCHASE' ? Icons.link : Icons.shopping_bag_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.marketplace}  ·  Qty ${request.quantity}  ·  ${request.shippingMethod}',
                      style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (request.costBreakdown != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '৳${request.costBreakdown!.totalBdt.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
