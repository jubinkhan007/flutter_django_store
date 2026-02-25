import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../returns/presentation/providers/return_provider.dart';
import '../../../returns/data/models/return_request_model.dart';


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

  Future<_ApproveData?> _promptApprove(BuildContext context, ReturnRequestModel rr) async {
    final controller = TextEditingController();
    DateTime? pickupStart = rr.pickupWindowStart;
    DateTime? pickupEnd = rr.pickupWindowEnd;
    final dropoffController = TextEditingController(text: rr.dropoffInstructions);

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
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial ?? now),
            );
            if (time == null) return null;
            return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
                    decoration: const InputDecoration(hintText: 'Optional note'),
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
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                value: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'WALLET', child: Text('Wallet credit')),
                  DropdownMenuItem(value: 'ORIGINAL', child: Text('Original method')),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                Navigator.pop(context, _RefundData(method: method, amount: amount));
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
          decoration: const InputDecoration(hintText: 'Gateway txn id, note, etc.'),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Returns (RMA)',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Expanded(
              child: Consumer<ReturnProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.vendorReturns.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }
                  if (provider.error != null && provider.vendorReturns.isEmpty) {
                    return Center(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  if (provider.vendorReturns.isEmpty) {
                    return const Center(
                      child: Text(
                        'No return requests',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () => provider.loadVendorReturns(),
                    child: ListView.builder(
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
                            await provider.vendorCompleteOriginalRefund(rr.id, reference: ref);
                          },
                          chipBuilder: _chip,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
    final canDecide = rr.status == 'SUBMITTED' || rr.status == 'ESCALATED';
    final canReceive =
        rr.status == 'VENDOR_APPROVED' ||
        rr.status == 'PICKUP_SCHEDULED' ||
        rr.status == 'DROPOFF_REQUESTED';
    final canRefund = rr.status == 'RECEIVED' || rr.status == 'REFUND_PENDING';
    final canCompleteOriginal = rr.status == 'REFUND_PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_return_outlined, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RMA ${rr.rmaNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              chipBuilder(rr.status, rr.status == 'ESCALATED' ? AppTheme.warning : AppTheme.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${rr.requestType} • ${rr.reason} • ${rr.fulfillment} • pref=${rr.refundMethodPreference}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (rr.fulfillment == 'PICKUP' &&
              (rr.pickupWindowStart != null || rr.pickupWindowEnd != null))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pickup: ${rr.pickupWindowStart?.toLocal().toString() ?? '-'} → ${rr.pickupWindowEnd?.toLocal().toString() ?? '-'}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          if (rr.fulfillment == 'DROPOFF' && rr.dropoffInstructions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Drop-off: ${rr.dropoffInstructions}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          ...rr.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${it.productName} × ${it.quantity}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canDecide)
                OutlinedButton(
                  onPressed: onApprove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: const BorderSide(color: AppTheme.success),
                  ),
                  child: const Text('Approve'),
                ),
              if (canDecide)
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  child: const Text('Reject'),
                ),
              if (canReceive)
                ElevatedButton(
                  onPressed: onReceived,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('Mark received'),
                ),
              if (canRefund)
                ElevatedButton(
                  onPressed: onRefund,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  child: const Text('Refund'),
                ),
              if (canCompleteOriginal)
                OutlinedButton(
                  onPressed: onCompleteOriginalRefund,
                  child: const Text('Mark refunded'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
