import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/vendor_wallet_model.dart';
import '../providers/vendor_provider.dart';

class VendorWalletScreen extends StatefulWidget {
  const VendorWalletScreen({super.key});

  @override
  State<VendorWalletScreen> createState() => _VendorWalletScreenState();
}

class _VendorWalletScreenState extends State<VendorWalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadWalletSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        title: Text(
          'Wallet',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<VendorProvider>().loadWalletSummary(),
        child: Builder(
          builder: (context) {
            if (provider.isWalletLoading && provider.walletSummary == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.walletError != null && provider.walletSummary == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 44,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          provider.walletError!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          text: 'Retry',
                          onPressed: () =>
                              context.read<VendorProvider>().loadWalletSummary(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final summary = provider.walletSummary;
            if (summary == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 1)],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _BalancesHeader(
                  balances: summary.balances,
                  primaryColor: primaryColor,
                ),
                if (summary.balances.debt > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DebtBalanceCard(debt: summary.balances.debt),
                ],
                const SizedBox(height: AppSpacing.md),
                _WithdrawCard(
                  balances: summary.balances,
                  primaryColor: primaryColor,
                  payoutMethods: summary.payoutMethods,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Transactions',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (summary.entries.isEmpty)
                  AppCard(
                    child: Text(
                      'No transactions yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  )
                else
                  ...summary.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _LedgerEntryTile(entry: e),
                    ),
                  ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BalancesHeader extends StatelessWidget {
  final VendorWalletBalances balances;
  final Color primaryColor;

  const _BalancesHeader({required this.balances, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Overview',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _BucketCard(
                  label: 'Available',
                  value: balances.available,
                  color: primaryColor,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BucketCard(
                  label: 'Pending',
                  value: balances.pending,
                  color: AppColors.warning,
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BucketCard(
                  label: 'In Processing',
                  value: balances.held,
                  color: AppColors.lightTextSecondary,
                  icon: Icons.lock_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lifetime earned',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '\$${balances.lifetimeEarned.toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lifetime withdrawn',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '\$${balances.lifetimeWithdrawn.toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _BucketCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtBalanceCard extends StatelessWidget {
  final double debt;

  const _DebtBalanceCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    final severity = debt > 100 ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: severity.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: severity.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: severity, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding Debt',
                  style: AppTextStyles.labelLarge.copyWith(color: severity),
                ),
                const SizedBox(height: 2),
                Text(
                  'A refund was processed while your balance was insufficient. '
                  'Your next earnings will automatically clear this debt.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '-\$${debt.toStringAsFixed(2)}',
            style: AppTextStyles.labelLarge.copyWith(
              color: severity,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawCard extends StatelessWidget {
  final VendorWalletBalances balances;
  final Color primaryColor;
  final List<VendorPayoutMethodModel> payoutMethods;

  const _WithdrawCard({
    required this.balances,
    required this.primaryColor,
    required this.payoutMethods,
  });

  @override
  Widget build(BuildContext context) {
    final canWithdraw = balances.available >= balances.minWithdrawal;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, color: primaryColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Withdraw Funds',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Minimum withdrawal: \$${balances.minWithdrawal.toStringAsFixed(2)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            text: 'Request Withdrawal',
            onPressed: canWithdraw ? () => _openWithdrawSheet(context) : null,
          ),
          if (!canWithdraw) ...[
            const SizedBox(height: 8),
            Text(
              'Add more earnings to reach the minimum withdrawal amount.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openWithdrawSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _WithdrawSheet(
        balances: balances,
        payoutMethods: payoutMethods,
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  final VendorWalletBalances balances;
  final List<VendorPayoutMethodModel> payoutMethods;

  const _WithdrawSheet({required this.balances, required this.payoutMethods});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();
  VendorPayoutMethodModel? _selectedMethod;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.payoutMethods.isNotEmpty) {
      _selectedMethod = widget.payoutMethods.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightOutline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Withdrawal Request',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Available: \$${widget.balances.available.toStringAsFixed(2)}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.account_balance, color: primaryColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VendorPayoutMethodModel>(
                      isExpanded: true,
                      value: _selectedMethod,
                      hint: const Text('Select payout method'),
                      items: widget.payoutMethods
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                '${m.label.isNotEmpty ? m.label : m.method}${m.isVerified ? ' (Verified)' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedMethod = value),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openAddMethodSheet(context),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '\$ ',
              labelText: 'Amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            text: 'Submit Request',
            isLoading: _submitting,
            onPressed: _canSubmit ? () => _submit(context) : null,
          ),
        ],
      ),
    );
  }

  bool get _canSubmit => (_selectedMethod != null) && !_submitting;

  Future<void> _submit(BuildContext context) async {
    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw) ?? 0;
    if (amount <= 0) return;

    if (amount > widget.balances.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount exceeds available balance.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok = await context.read<VendorProvider>().requestPayout(
          amount: amount,
          bankDetails: _selectedMethod!.toBankDetailsText(),
        );
    if (!context.mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal request submitted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = context.read<VendorProvider>().walletError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to submit request.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openAddMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const _AddPayoutMethodSheet(),
    );
  }
}

class _AddPayoutMethodSheet extends StatefulWidget {
  const _AddPayoutMethodSheet();

  @override
  State<_AddPayoutMethodSheet> createState() => _AddPayoutMethodSheetState();
}

class _AddPayoutMethodSheetState extends State<_AddPayoutMethodSheet> {
  String _method = 'BANK';
  final _labelController = TextEditingController();
  final _field1Controller = TextEditingController();
  final _field2Controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _field1Controller.dispose();
    _field2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;
    final primaryColor = Theme.of(context).primaryColor;

    final field1Label = _method == 'BANK' ? 'Bank name' : 'Wallet number';
    final field2Label = _method == 'BANK' ? 'Account number' : 'Account name (optional)';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightOutline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Add Payout Method',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.account_balance, color: primaryColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _method,
                      items: const [
                        DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                        DropdownMenuItem(value: 'BKASH', child: Text('bKash')),
                        DropdownMenuItem(value: 'NAGAD', child: Text('Nagad')),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'BANK'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Label (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _field1Controller,
            decoration: InputDecoration(
              labelText: field1Label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _field2Controller,
            decoration: InputDecoration(
              labelText: field2Label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            text: 'Save',
            isLoading: _saving,
            onPressed: _saving ? null : () => _save(context),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final details = <String, dynamic>{
      if (_method == 'BANK') 'bank_name': _field1Controller.text.trim(),
      if (_method == 'BANK') 'account_number': _field2Controller.text.trim(),
      if (_method != 'BANK') 'wallet_number': _field1Controller.text.trim(),
      if (_field2Controller.text.trim().isNotEmpty) 'name': _field2Controller.text.trim(),
    };

    setState(() => _saving = true);
    final ok = await context.read<VendorProvider>().createPayoutMethod(
          method: _method,
          label: _labelController.text.trim(),
          details: details,
        );
    if (!context.mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout method saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = context.read<VendorProvider>().walletError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to save method.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _LedgerEntryTile extends StatelessWidget {
  final VendorLedgerEntry entry;

  const _LedgerEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isCredit = entry.direction == 'CREDIT';
    final amountColor = isCredit ? AppColors.success : AppColors.error;

    final isRefundDebit = entry.entryType == 'REFUND_DEBIT';

    final typeColor = switch (entry.entryType) {
      'SALE_CREDIT_PENDING' => AppColors.success,
      'SETTLEMENT_RELEASE' => primaryColor,
      'PAYOUT_REQUEST_HOLD' => AppColors.warning,
      'PAYOUT_REJECTED_RELEASE' => primaryColor,
      'PAYOUT_PAID' => AppColors.error,
      'REFUND_DEBIT' => AppColors.error,
      _ => AppColors.lightTextSecondary,
    };

    final tileIcon = isRefundDebit
        ? Icons.undo_rounded
        : (isCredit ? Icons.call_received_rounded : Icons.call_made_rounded);

    final subtitle = isRefundDebit
        ? 'Refund • ${entry.referenceType} #${entry.referenceId}'
        : '${entry.bucket} • ${entry.referenceType} #${entry.referenceId}';

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tileIcon,
              size: 18,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description.isNotEmpty ? entry.description : entry.entryType,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isCredit ? '+' : '-'}\$${entry.amount.toStringAsFixed(2)}',
            style: AppTextStyles.labelLarge.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
