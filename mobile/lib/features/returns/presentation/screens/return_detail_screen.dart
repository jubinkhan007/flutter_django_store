import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../support/presentation/screens/ticket_chat_screen.dart';
import '../../data/models/return_request_model.dart';
import '../../data/repositories/return_repository.dart';
import '../providers/return_provider.dart';


class ReturnDetailScreen extends StatefulWidget {
  final ReturnRequestModel returnRequest;

  const ReturnDetailScreen({super.key, required this.returnRequest});

  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  late ReturnRequestModel _rr = widget.returnRequest;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final repo = context.read<ReturnRepository>();
      final fresh = await repo.getReturnDetail(_rr.id);
      if (!mounted) return;
      setState(() => _rr = fresh);
    } catch (_) {
      // ignore; keep showing current snapshot
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  bool _canEscalate(ReturnRequestModel rr) {
    if (rr.status == 'VENDOR_REJECTED') return true;
    if (rr.status == 'SUBMITTED' && rr.vendorResponseDueAt != null) {
      return rr.vendorResponseDueAt!.isBefore(DateTime.now());
    }
    return false;
  }

  Future<void> _confirmAndEscalate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate to Admin'),
        content: const Text(
          'This will open a dispute ticket for admin mediation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final provider = context.read<ReturnProvider>();
    final updated = await provider.escalateReturn(_rr.id);
    if (!mounted) return;

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to escalate')),
      );
      return;
    }
    setState(() => _rr = updated);

    final ticketId = updated.disputeTicketId;
    if (ticketId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketChatScreen(ticketId: ticketId)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escalated, but ticket is not linked yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final refund = _rr.refunds.isEmpty ? null : _rr.refunds.first;
    final auth = context.watch<AuthProvider>();
    final isCustomer = auth.user?.type == 'CUSTOMER';
    final canEscalate = isCustomer && _canEscalate(_rr);
    final canViewDispute = _rr.disputeTicketId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_rr.rmaNumber),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (canViewDispute)
            Container(
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
                  const Icon(Icons.gavel_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Dispute ticket is linked to this return.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final id = _rr.disputeTicketId;
                      if (id == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TicketChatScreen(ticketId: id)),
                      );
                    },
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
          if (canViewDispute) const SizedBox(height: AppSpacing.md),
          _kv('Status', _rr.status),
          _kv('Type', _rr.requestType),
          _kv('Reason', _rr.reason),
          if (_rr.reasonDetails.isNotEmpty) _kv('Reason details', _rr.reasonDetails),
          _kv('Fulfillment', _rr.fulfillment),
          if (_rr.fulfillment == 'PICKUP' &&
              (_rr.pickupWindowStart != null || _rr.pickupWindowEnd != null))
            _kv(
              'Pickup window',
              '${_rr.pickupWindowStart?.toLocal().toString() ?? '-'} → ${_rr.pickupWindowEnd?.toLocal().toString() ?? '-'}',
            ),
          if (_rr.fulfillment == 'DROPOFF' && _rr.dropoffInstructions.isNotEmpty)
            _kv('Drop-off', _rr.dropoffInstructions),
          _kv('Refund preference', _rr.refundMethodPreference),
          if (_rr.customerNote.isNotEmpty) _kv('Your note', _rr.customerNote),
          if (_rr.vendorNote.isNotEmpty) _kv('Vendor note', _rr.vendorNote),
          if (_rr.vendorResponseDueAt != null)
            _kv('Vendor response due', _rr.vendorResponseDueAt!.toLocal().toString()),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ..._rr.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${it.productName} × ${it.quantity} (${it.condition})',
                style: const TextStyle(color: AppColors.lightTextSecondary),
              ),
            ),
          ),
          if (refund != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Refund',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _kv('Status', refund.status),
            _kv('Method', refund.method),
            _kv('Amount', '\$${refund.amount.toStringAsFixed(2)}'),
          ],
          if (canEscalate) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _confirmAndEscalate,
              icon: const Icon(Icons.gavel_outlined),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              label: const Text('Escalate to Admin'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use escalation if you and the vendor can’t agree.',
              style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              k,
              style: const TextStyle(color: AppColors.lightTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: AppColors.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

