import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../returns/presentation/providers/return_provider.dart';
import '../../../returns/data/models/return_request_model.dart';
import '../../../support/presentation/screens/ticket_chat_screen.dart';

class VendorReturnsScreen extends StatefulWidget {
  const VendorReturnsScreen({super.key});

  @override
  State<VendorReturnsScreen> createState() => _VendorReturnsScreenState();
}

class _VendorReturnsScreenState extends State<VendorReturnsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReturnProvider>().loadVendorReturns();
    });
  }

  Future<_ApproveData?> _promptApprove(
    BuildContext context,
    ReturnRequestModel rr,
  ) async {
    final controller = TextEditingController();
    DateTime? pickupStart = rr.pickupWindowStart;
    DateTime? pickupEnd = rr.pickupWindowEnd;
    final dropoffController = TextEditingController(
      text: rr.dropoffInstructions,
    );

    final res = await showDialog<_ApproveData>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<DateTime?> pickDateTime(DateTime? initial) async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: initial ?? now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 30)),
            );
            if (date == null) return null;
            if (!context.mounted) return null;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial ?? now),
            );
            if (time == null || !context.mounted) return null;
            return DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          }

          String fmt(DateTime? dt) {
            if (dt == null) return 'Not set';
            return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }

          return AlertDialog(
            title: const Text('Approve return'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Optional note',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  if (rr.fulfillment == 'PICKUP') ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pickup window start'),
                      subtitle: Text(fmt(pickupStart)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final dt = await pickDateTime(pickupStart);
                        if (dt == null) return;
                        setState(() => pickupStart = dt);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pickup window end'),
                      subtitle: Text(fmt(pickupEnd)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final dt = await pickDateTime(pickupEnd ?? pickupStart);
                        if (dt == null) return;
                        setState(() => pickupEnd = dt);
                      },
                    ),
                    const Text(
                      'Tip: setting both times moves status to PICKUP_SCHEDULED.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: dropoffController,
                      decoration: const InputDecoration(
                        labelText: 'Drop-off instructions',
                        hintText: 'Address, hours, what to include, etc.',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _ApproveData(
                      note: controller.text.trim(),
                      pickupWindowStart: pickupStart,
                      pickupWindowEnd: pickupEnd,
                      dropoffInstructions: dropoffController.text.trim(),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    dropoffController.dispose();
    return res;
  }

  Future<_RefundData?> _promptRefund(BuildContext context) async {
    String method = 'WALLET';
    final amountController = TextEditingController();
    final res = await showDialog<_RefundData>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Initiate refund'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(
                    value: 'WALLET',
                    child: Text('Wallet credit'),
                  ),
                  DropdownMenuItem(
                    value: 'ORIGINAL',
                    child: Text('Original method'),
                  ),
                ],
                onChanged: (v) => setState(() => method = v ?? 'WALLET'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Partial amount (optional)',
                  hintText: 'Leave blank for full amount',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final raw = amountController.text.trim();
                final amount = raw.isEmpty ? null : double.tryParse(raw);
                Navigator.pop(
                  context,
                  _RefundData(method: method, amount: amount),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    return res;
  }

  Future<String?> _promptReference(BuildContext context) async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund reference (optional)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Gateway txn id, note, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  Future<String?> _promptReject(BuildContext context) async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject return'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(31), // ~12%
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns (RMA)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<ReturnProvider>().loadVendorReturns(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<ReturnProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.vendorReturns.isEmpty) {
            return const AppLoadingState(message: 'Loading returns...');
          }

          if (provider.error != null && provider.vendorReturns.isEmpty) {
            return AppErrorState(
              message: provider.error!,
              onRetry: () => provider.loadVendorReturns(),
            );
          }

          if (provider.vendorReturns.isEmpty) {
            return AppEmptyState(
              icon: Icons.assignment_return_outlined,
              title: 'No return requests',
              message: 'Customer return requests will appear here.',
              buttonText: 'Refresh',
              onAction: () => provider.loadVendorReturns(),
            );
          }

          return RefreshIndicator(
            color: Theme.of(context).primaryColor,
            onRefresh: () => provider.loadVendorReturns(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.vendorReturns.length,
              itemBuilder: (context, index) {
                final rr = provider.vendorReturns[index];
                return _ReturnCard(
                  rr: rr,
                  onApprove: () async {
                    final data = await _promptApprove(context, rr);
                    if (data == null) return;
                    await provider.vendorApproveWithDetails(
                      rr.id,
                      note: data.note,
                      pickupWindowStart: data.pickupWindowStart,
                      pickupWindowEnd: data.pickupWindowEnd,
                      dropoffInstructions: data.dropoffInstructions,
                    );
                  },
                  onReject: () async {
                    final note = await _promptReject(context);
                    if (note == null) return;
                    await provider.vendorReject(rr.id, note: note);
                  },
                  onReceived: () async {
                    await provider.vendorMarkReceived(rr.id);
                  },
                  onRefund: () async {
                    final data = await _promptRefund(context);
                    if (data == null) return;
                    await provider.vendorInitiateRefund(
                      rr.id,
                      method: data.method,
                      amount: data.amount,
                    );
                  },
                  onCompleteOriginalRefund: () async {
                    final ref = await _promptReference(context);
                    if (ref == null) return;
                    await provider.vendorCompleteOriginalRefund(
                      rr.id,
                      reference: ref,
                    );
                  },
                  chipBuilder: _chip,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApproveData {
  final String note;
  final DateTime? pickupWindowStart;
  final DateTime? pickupWindowEnd;
  final String dropoffInstructions;

  const _ApproveData({
    required this.note,
    required this.pickupWindowStart,
    required this.pickupWindowEnd,
    required this.dropoffInstructions,
  });
}

class _RefundData {
  final String method;
  final double? amount;

  const _RefundData({required this.method, required this.amount});
}

class _ReturnCard extends StatelessWidget {
  final ReturnRequestModel rr;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReceived;
  final VoidCallback onRefund;
  final VoidCallback onCompleteOriginalRefund;
  final Widget Function(String, Color) chipBuilder;

  const _ReturnCard({
    required this.rr,
    required this.onApprove,
    required this.onReject,
    required this.onReceived,
    required this.onRefund,
    required this.onCompleteOriginalRefund,
    required this.chipBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final primaryGradient = isDark
        ? AppGradients.darkPrimary
        : AppGradients.lightPrimary;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final canDecide = rr.status == 'SUBMITTED' || rr.status == 'ESCALATED';
    final canReceive =
        rr.status == 'VENDOR_APPROVED' ||
        rr.status == 'PICKUP_SCHEDULED' ||
        rr.status == 'DROPOFF_REQUESTED';
    final hasPendingOriginalRefund = rr.refunds.any(
      (r) => r.method == 'ORIGINAL' && r.status == 'PENDING',
    );
    final canRefund = rr.status == 'RECEIVED';
    final canCompleteOriginal =
        rr.status == 'REFUND_PENDING' && hasPendingOriginalRefund;

    final statusColor = switch (rr.status) {
      'ESCALATED' => AppColors.warning,
      'SUBMITTED' => primary,
      'VENDOR_APPROVED' => primary,
      'PICKUP_SCHEDULED' => primary,
      'DROPOFF_REQUESTED' => primary,
      'RECEIVED' => AppColors.success,
      'REFUND_PENDING' => AppColors.warning,
      'REFUNDED' => AppColors.success,
      'VENDOR_REJECTED' => AppColors.error,
      _ => textSecondary,
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.assignment_return_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RMA',
                      style: AppTextStyles.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rr.rmaNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              chipBuilder(rr.status, statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${rr.requestType} • ${rr.reason} • ${rr.fulfillment} • pref=${rr.refundMethodPreference}',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          if (rr.fulfillment == 'PICKUP' &&
              (rr.pickupWindowStart != null || rr.pickupWindowEnd != null))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pickup: ${rr.pickupWindowStart?.toLocal().toString() ?? '-'} → ${rr.pickupWindowEnd?.toLocal().toString() ?? '-'}',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
          if (rr.fulfillment == 'DROPOFF' && rr.dropoffInstructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Drop-off: ${rr.dropoffInstructions}',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          ...rr.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${it.productName} × ${it.quantity}',
                style: TextStyle(color: textPrimary, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (rr.disputeTicketId != null)
                OutlinedButton.icon(
                  onPressed: () {
                    final id = rr.disputeTicketId;
                    if (id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketChatScreen(ticketId: id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.gavel_outlined, size: 18),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  label: const Text('View dispute'),
                ),
              if (canDecide)
                OutlinedButton(
                  onPressed: onApprove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              if (canDecide)
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              if (canReceive)
                ElevatedButton(
                  onPressed: onReceived,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Mark received'),
                ),
              if (canRefund)
                ElevatedButton(
                  onPressed: onRefund,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Refund'),
                ),
              if (canCompleteOriginal)
                OutlinedButton(
                  onPressed: onCompleteOriginalRefund,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Mark refunded'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
