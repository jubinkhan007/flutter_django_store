import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/order_model.dart';
import '../widgets/shipment_timeline.dart';
import '../../../support/presentation/screens/create_ticket_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

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
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'PAID':
        return AppColors.success;
      case 'REFUNDED':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSubOrders = order.subOrders.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Order #${order.id}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Order summary header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(order.createdAt),
                              style: const TextStyle(
                                color: AppColors.lightTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Subtotal',
                    value: '\$${order.subtotalAmount.toStringAsFixed(2)}',
                  ),
                  if (order.discountAmount > 0)
                    _SummaryRow(
                      label: 'Discount',
                      value: '-\$${order.discountAmount.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                    ),
                  _SummaryRow(
                    label: 'Total',
                    value: '\$${order.totalAmount.toStringAsFixed(2)}',
                    bold: true,
                    valueColor: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Payment: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _paymentColor(order.paymentStatus).withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${order.paymentMethod} · ${order.paymentStatus}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _paymentColor(order.paymentStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Need help CTA
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Need help with this order?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateTicketScreen(
                              prefillCategory: 'ORDER',
                              prefillSubject: 'Issue with Order #${order.id}',
                              prefillOrderId: order.id,
                            ),
                          ),
                        );
                      },
                      child: const Text('Contact support'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Delivery address
          if (order.deliveryAddress != null) ...[
            const _SectionHeader(title: 'Delivery Address'),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.deliveryAddress!.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.deliveryAddress!.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${order.deliveryAddress!.addressLine}, '
                      '${order.deliveryAddress!.area}, '
                      '${order.deliveryAddress!.city}',
                      style: const TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Sub-orders or flat items
          if (hasSubOrders) ...[
            _SectionHeader(title: 'Shipments (${order.subOrders.length})'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _SubOrderCard(
                  subOrder: order.subOrders[i],
                  statusColor: _statusColor,
                ),
                childCount: order.subOrders.length,
              ),
            ),
          ] else if (order.items.isNotEmpty) ...[
            const _SectionHeader(title: 'Items'),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                ),
                child: Column(
                  children: order.items.map((item) => _ItemRow(item: item)).toList(),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 16, AppSpacing.md, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.lightTextSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() {
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
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.lightTextPrimary : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (bold ? AppColors.lightTextPrimary : AppColors.lightTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItemModel item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 5, color: AppColors.lightTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.productName ?? 'Product'} × ${item.quantity}',
              style: const TextStyle(
                color: AppColors.lightTextSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.lightTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubOrderCard extends StatelessWidget {
  final SubOrderModel subOrder;
  final Color Function(String) statusColor;

  const _SubOrderCard({required this.subOrder, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(subOrder.status);
    final hasTracking = subOrder.trackingNumber != null &&
        subOrder.trackingNumber!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: [
                // Vendor avatar
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    subOrder.vendorStoreName.isNotEmpty
                        ? subOrder.vendorStoreName[0].toUpperCase()
                        : 'V',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subOrder.vendorStoreName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subOrder.packageLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: subOrder.status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items
                ...subOrder.items.map((item) => _ItemRow(item: item)),

                // Total
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Shipment total',
                        style: TextStyle(
                          color: AppColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '\$${subOrder.totalAmount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tracking row
                if (hasTracking) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 14,
                        color: AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subOrder.courierName != null &&
                                subOrder.courierName!.isNotEmpty)
                              Text(
                                subOrder.courierName!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    subOrder.trackingNumber!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: subOrder.trackingNumber!,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tracking number copied'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.copy_outlined,
                                      size: 14,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (subOrder.trackingUrl != null &&
                          subOrder.trackingUrl!.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            final uri = Uri.parse(subOrder.trackingUrl!);
                            try {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {}
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 28),
                          ),
                          child: const Text(
                            'Track',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 14,
                        color: AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subOrder.provisionStatus == 'REQUESTED'
                                  ? 'Carrier assignment pending'
                                  : subOrder.provisionStatus == 'FAILED'
                                      ? 'Failed to provision shipment'
                                      : 'Tracking not available yet',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (subOrder.provisionStatus == 'FAILED' &&
                                subOrder.lastError.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subOrder.lastError,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Shipment timeline
                if (subOrder.events.isNotEmpty || !hasTracking) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  const Text(
                    'Tracking History',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShipmentTimeline(events: subOrder.events),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
