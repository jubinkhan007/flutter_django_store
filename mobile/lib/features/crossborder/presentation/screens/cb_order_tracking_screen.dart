import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../data/models/cb_models.dart';
import '../providers/crossborder_provider.dart';

class CbOrderTrackingScreen extends StatefulWidget {
  final int requestId;

  const CbOrderTrackingScreen({super.key, required this.requestId});

  @override
  State<CbOrderTrackingScreen> createState() => _CbOrderTrackingScreenState();
}

class _CbOrderTrackingScreenState extends State<CbOrderTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CrossBorderProvider>().openRequest(widget.requestId);
    });
  }

  Future<void> _markReceived(CrossBorderOrderRequest req) async {
    final ok = await context.read<CrossBorderProvider>().markReceived(req.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<CrossBorderProvider>().actionError ?? 'Failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Tracking')),
      body: Consumer<CrossBorderProvider>(
        builder: (context, provider, _) {
          if (provider.activeLoading && provider.activeRequest == null) {
            return const AppLoadingState(message: 'Loading order...');
          }
          final req = provider.activeRequest;
          if (req == null) {
            return const Center(child: Text('Order not found'));
          }
          return RefreshIndicator(
            onRefresh: () => provider.openRequest(widget.requestId),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // ── Status banner ──
                _StatusBanner(status: req.status),
                const SizedBox(height: 16),

                // ── Order info ──
                _InfoCard(
                  title: 'Order Details',
                  rows: [
                    _Row('Item', req.title),
                    _Row('Marketplace', req.marketplace),
                    _Row('Quantity', '${req.quantity}'),
                    _Row('Shipping', req.shippingMethod),
                    _Row('Type', req.requestType == 'LINK_PURCHASE' ? 'Buy by Link' : 'Catalog Item'),
                    _Row('Created', req.createdAt),
                    if (req.shippedIntlAt != null) _Row('Shipped Internationally', req.shippedIntlAt!),
                    if (req.deliveredAt != null) _Row('Delivered', req.deliveredAt!),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Cost breakdown ──
                if (req.costBreakdown != null)
                  _InfoCard(
                    title: 'Cost Breakdown',
                    rows: [
                      _Row('Item Price', '${req.costBreakdown!.currency} ${req.costBreakdown!.itemPriceForeign.toStringAsFixed(2)}'),
                      _Row('Item Price (BDT)', '৳${req.costBreakdown!.itemPriceBdt.toStringAsFixed(0)}'),
                      _Row('Intl Shipping', '৳${req.costBreakdown!.intlShippingBdt.toStringAsFixed(0)}'),
                      _Row('Service Fee', '৳${req.costBreakdown!.serviceFeeBdt.toStringAsFixed(0)}'),
                      _Row('Customs (est.)', '৳${req.costBreakdown!.customsEstBdt.toStringAsFixed(0)}'),
                      _Row('Total Charged', '৳${req.costBreakdown!.totalBdt.toStringAsFixed(0)}', bold: true),
                    ],
                  ),
                const SizedBox(height: 12),

                // ── Carrier / tracking ──
                if (req.hasTracking)
                  _InfoCard(
                    title: 'Carrier Tracking',
                    rows: [
                      if (req.carrierName.isNotEmpty) _Row('Carrier', req.carrierName),
                      if (req.trackingNumber.isNotEmpty) _Row('Tracking #', req.trackingNumber),
                    ],
                    trailing: req.trackingUrl.isNotEmpty
                        ? OutlinedButton.icon(
                            onPressed: () => _openUrl(req.trackingUrl),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Track on carrier site'),
                          )
                        : null,
                  ),

                const SizedBox(height: 20),

                // ── Customs held notice ──
                if (req.status == 'CUSTOMS_HELD')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your package is held at customs. Our team is working to resolve this. '
                            'You may need to pay customs duties directly to release your shipment.',
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Mark received ──
                if (req.status == 'OUT_FOR_DELIVERY' || req.status == 'DELIVERED')
                  Consumer<CrossBorderProvider>(
                    builder: (context, provider, _) => FilledButton.icon(
                      onPressed: (req.status == 'DELIVERED' || provider.actionLoading)
                          ? null
                          : () => _markReceived(req),
                      icon: provider.actionLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(req.status == 'DELIVERED' ? 'Delivered' : 'Mark as Received'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ──

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  static Color _colorFor(String s) {
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
      case 'CANCELLED':
      case 'REFUND_IN_PROGRESS':
        return AppColors.error;
      case 'CUSTOMS_HELD':
        return AppColors.warning;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    final label = status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Status', style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  final bool bold;
  _Row(this.label, this.value, {this.bold = false});
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  final Widget? trailing;
  const _InfoCard({required this.title, required this.rows, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightTextSecondary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.lightTextSecondary)),
          const SizedBox(height: 10),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      r.value,
                      style: TextStyle(fontSize: 13, fontWeight: r.bold ? FontWeight.w700 : FontWeight.normal),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(height: 10), trailing!],
        ],
      ),
    );
  }
}
