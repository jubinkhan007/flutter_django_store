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
  int _selectedTab = 0; // 0: Transactions, 1: Payout Requests

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
          'Vendor Wallet & Disbursals',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
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
                          onPressed: () => context
                              .read<VendorProvider>()
                              .loadWalletSummary(),
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
                // 1. Balance Overview Header
                _BalancesHeader(
                  balances: summary.balances,
                  primaryColor: primaryColor,
                ),

                if (summary.balances.debt > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DebtBalanceCard(debt: summary.balances.debt),
                ],

                const SizedBox(height: AppSpacing.md),

                // 2. Automated Scheduled Payouts Configuration Card
                _AutoPayoutCard(
                  autoPayout: summary.autoPayout,
                  payoutMethods: summary.payoutMethods,
                ),

                const SizedBox(height: AppSpacing.md),

                // 3. Payout Methods (bKash / Nagad / Bank) & Verification
                _PayoutMethodsCard(
                  payoutMethods: summary.payoutMethods,
                  primaryColor: primaryColor,
                ),

                const SizedBox(height: AppSpacing.md),

                // 4. Manual / Instant Withdrawal Card
                _WithdrawCard(
                  balances: summary.balances,
                  primaryColor: primaryColor,
                  payoutMethods: summary.payoutMethods,
                ),

                const SizedBox(height: AppSpacing.lg),

                // 5. Tabs: Recent Transactions vs Payout Requests History
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _selectedTab == 0 ? primaryColor : AppColors.lightOutline,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Transactions (${summary.entries.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0 ? Colors.white : AppColors.lightTextPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _selectedTab == 1 ? primaryColor : AppColors.lightOutline,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Payouts (${summary.payoutRequests.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1 ? Colors.white : AppColors.lightTextPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                if (_selectedTab == 0) ...[
                  if (summary.entries.isEmpty)
                    AppCard(
                      child: Text(
                        'No transactions recorded yet.',
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
                ] else ...[
                  if (summary.payoutRequests.isEmpty)
                    AppCard(
                      child: Text(
                        'No payout requests made yet.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    )
                  else
                    ...summary.payoutRequests.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PayoutRequestTile(payout: p),
                      ),
                    ),
                ],

                SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── 1. Balances Header ──
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Balance Overview',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Text(
                  'BDT ৳',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
                  color: Colors.blueGrey,
                  icon: Icons.lock_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lifetime Earned',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '৳${balances.lifetimeEarned.toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lifetime Withdrawn',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '৳${balances.lifetimeWithdrawn.toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w700,
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
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            '৳${value.toStringAsFixed(0)}',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightTextSecondary,
              fontSize: 11,
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
                  'Outstanding Debt Balance',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: severity,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A customer refund was completed while balance was insufficient. Subsequent settlement releases will automatically clear this.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '-৳${debt.toStringAsFixed(2)}',
            style: AppTextStyles.labelLarge.copyWith(
              color: severity,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Automated Scheduled Payouts Configuration Card ──
class _AutoPayoutCard extends StatelessWidget {
  final VendorAutoPayoutSettings? autoPayout;
  final List<VendorPayoutMethodModel> payoutMethods;

  const _AutoPayoutCard({
    required this.autoPayout,
    required this.payoutMethods,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = autoPayout?.isEnabled ?? false;
    final schedule = autoPayout?.schedule ?? 'WEEKLY';
    final threshold = autoPayout?.threshold ?? 1000.0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isEnabled ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.autorenew_rounded,
                  color: isEnabled ? Colors.green : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automated Scheduled Disbursal',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isEnabled
                          ? 'Auto-disburses when balance reaches ৳${threshold.toStringAsFixed(0)} ($schedule)'
                          : 'Disabled • Tap to configure scheduled payouts',
                      style: AppTextStyles.caption.copyWith(
                        color: isEnabled ? Colors.green.shade700 : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openAutoPayoutSheet(context),
                child: Text(
                  isEnabled ? 'Edit' : 'Enable',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openAutoPayoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _AutoPayoutSettingsSheet(
        settings: autoPayout,
        payoutMethods: payoutMethods,
      ),
    );
  }
}

class _AutoPayoutSettingsSheet extends StatefulWidget {
  final VendorAutoPayoutSettings? settings;
  final List<VendorPayoutMethodModel> payoutMethods;

  const _AutoPayoutSettingsSheet({
    required this.settings,
    required this.payoutMethods,
  });

  @override
  State<_AutoPayoutSettingsSheet> createState() => _AutoPayoutSettingsSheetState();
}

class _AutoPayoutSettingsSheetState extends State<_AutoPayoutSettingsSheet> {
  late bool _isEnabled;
  late String _schedule;
  late TextEditingController _thresholdController;
  int? _preferredMethodId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.settings?.isEnabled ?? false;
    _schedule = widget.settings?.schedule ?? 'WEEKLY';
    _thresholdController = TextEditingController(
      text: (widget.settings?.threshold ?? 1000).toStringAsFixed(0),
    );
    _preferredMethodId = widget.settings?.preferredMethodId;
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

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
            'Auto-Payout Configuration',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Funds are automatically disbursed to your verified bKash, Nagad, or Bank account according to schedule.',
            style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Enable toggle
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable Automated Disbursal', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Disburse balance automatically without manual requests'),
            value: _isEnabled,
            activeTrackColor: AppColors.primary,
            onChanged: (val) => setState(() => _isEnabled = val),
          ),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          // Schedule selector
          const Text('Disbursal Frequency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildScheduleChip('Weekly', 'WEEKLY'),
              const SizedBox(width: 8),
              _buildScheduleChip('Bi-weekly', 'BIWEEKLY'),
              const SizedBox(width: 8),
              _buildScheduleChip('Monthly', 'MONTHLY'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Threshold amount
          const Text('Minimum Balance Threshold (BDT)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '৳ ',
              hintText: '1000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [500, 1000, 2500, 5000].map((val) {
              return ActionChip(
                label: Text('৳$val', style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _thresholdController.text = '$val'),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            text: 'Save Auto-Payout Settings',
            isLoading: _saving,
            onPressed: _saveSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleChip(String label, String value) {
    final selected = _schedule == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.lightTextPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _schedule = value);
      },
    );
  }

  Future<void> _saveSettings() async {
    final amount = double.tryParse(_thresholdController.text.trim()) ?? 1000.0;
    setState(() => _saving = true);

    final settings = VendorAutoPayoutSettings(
      isEnabled: _isEnabled,
      schedule: _schedule,
      threshold: amount,
      preferredMethodId: _preferredMethodId,
    );

    final ok = await context.read<VendorProvider>().updateAutoPayoutSettings(settings);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-payout settings updated.'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update settings.'), backgroundColor: AppColors.error),
      );
    }
  }
}

// ── 3. Payout Methods (bKash / Nagad / Bank) & Verification ──
class _PayoutMethodsCard extends StatelessWidget {
  final List<VendorPayoutMethodModel> payoutMethods;
  final Color primaryColor;

  const _PayoutMethodsCard({
    required this.payoutMethods,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Disbursal Accounts',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _openAddMethodSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (payoutMethods.isEmpty)
            Text(
              'No account added. Add a bKash, Nagad, or Bank account for payouts.',
              style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary),
            )
          else
            ...payoutMethods.map((m) => _buildMethodItem(context, m)),
        ],
      ),
    );
  }

  Widget _buildMethodItem(BuildContext context, VendorPayoutMethodModel method) {
    final isBkash = method.method == 'BKASH';
    final isNagad = method.method == 'NAGAD';
    final isBank = method.method == 'BANK';

    final Color badgeColor = isBkash
        ? const Color(0xFFE2136E) // bKash Pink
        : (isNagad ? const Color(0xFFF7921E) : Colors.indigo); // Nagad Orange

    String detailsText = '';
    if (isBank) {
      detailsText = '${method.details['bank_name'] ?? 'Bank'} • Acct: ${method.details['account_number'] ?? ''}';
    } else {
      detailsText = '${method.details['wallet_number'] ?? method.details['phone'] ?? ''}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.lightOutline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              method.method,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.label.isNotEmpty ? method.label : method.method,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  detailsText,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (method.isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green),
                  SizedBox(width: 3),
                  Text('Verified', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            TextButton(
              onPressed: () async {
                final ok = await context.read<VendorProvider>().verifyPayoutMethod(method.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Account verified successfully!' : 'Account verification failed.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Verify Now', style: TextStyle(fontSize: 11, color: AppColors.warning)),
            ),
        ],
      ),
    );
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

// ── 4. Manual / Instant Withdrawal Card ──
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
                  'Request Manual Withdrawal',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Minimum withdrawal: ৳${balances.minWithdrawal.toStringAsFixed(2)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            text: 'Request Instant Disbursal',
            onPressed: canWithdraw ? () => _openWithdrawSheet(context) : null,
          ),
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
      builder: (_) => _WithdrawSheet(balances: balances),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  final VendorWalletBalances balances;

  const _WithdrawSheet({required this.balances});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();
  VendorPayoutMethodModel? _selectedMethod;
  bool _autoDisburse = true;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorProvider>();
    final payoutMethods = provider.walletSummary?.payoutMethods ?? [];

    if (payoutMethods.isNotEmpty && _selectedMethod == null) {
      _selectedMethod = payoutMethods.first;
    }

    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
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
            'Withdrawal Request & Disbursal',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available for payout: ৳${widget.balances.available.toStringAsFixed(2)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Payout method selector
          if (payoutMethods.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('No payout accounts added yet.', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => _openAddMethodSheet(context),
                    child: const Text('Add Account'),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(10),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<VendorPayoutMethodModel>(
                  isExpanded: true,
                  value: _selectedMethod,
                  items: payoutMethods.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${m.method} • ${m.label.isNotEmpty ? m.label : 'Account'} (${m.isVerified ? 'Verified' : 'Unverified'})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMethod = val),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.sm),

          // Amount field
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '৳ ',
              labelText: 'Withdrawal Amount',
              hintText: '500.00',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 8),

          // Quick amounts
          Row(
            children: [
              ActionChip(
                label: const Text('All Available'),
                onPressed: () => setState(() => _amountController.text = widget.balances.available.toStringAsFixed(0)),
              ),
              const SizedBox(width: 6),
              ActionChip(
                label: const Text('৳1,000'),
                onPressed: () => setState(() => _amountController.text = '1000'),
              ),
              const SizedBox(width: 6),
              ActionChip(
                label: const Text('৳2,500'),
                onPressed: () => setState(() => _amountController.text = '2500'),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Instant Gateway Disbursal switch
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoDisburse,
            title: const Text(
              '⚡ Instant Disburse via Gateway',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: const Text(
              'Simulate immediate API transfer to bKash / Nagad / Bank EFT.',
              style: TextStyle(fontSize: 11),
            ),
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _autoDisburse = val ?? true),
          ),

          const SizedBox(height: AppSpacing.md),

          PrimaryButton(
            text: _autoDisburse ? 'Disburse Now' : 'Submit Payout Request',
            isLoading: _submitting,
            onPressed: (_selectedMethod != null && !_submitting) ? _submit : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw) ?? 0;
    if (amount <= 0) return;

    if (amount > widget.balances.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount exceeds available balance.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final vendorProvider = context.read<VendorProvider>();

    setState(() => _submitting = true);
    final ok = await vendorProvider.requestPayout(
      amount: amount,
      bankDetails: _selectedMethod!.toBankDetailsText(),
      payoutMethodId: _selectedMethod!.id,
      autoDisburse: _autoDisburse,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_autoDisburse ? 'Disbursal executed successfully!' : 'Payout request submitted.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = vendorProvider.walletError;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to submit payout.'),
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

// ── 5. Add Payout Method Modal ──
class _AddPayoutMethodSheet extends StatefulWidget {
  const _AddPayoutMethodSheet();

  @override
  State<_AddPayoutMethodSheet> createState() => _AddPayoutMethodSheetState();
}

class _AddPayoutMethodSheetState extends State<_AddPayoutMethodSheet> {
  String _method = 'BKASH';
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
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final primaryColor = Theme.of(context).primaryColor;

    final field1Label = _method == 'BANK' ? 'Bank Name' : '11-digit Wallet Number (e.g. 01712345678)';
    final field2Label = _method == 'BANK' ? 'Account Number' : 'Account Holder Name (optional)';

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
            'Add Disbursal Account',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Method Selector
          Row(
            children: [
              _buildTypeChip('bKash', 'BKASH', const Color(0xFFE2136E)),
              const SizedBox(width: 8),
              _buildTypeChip('Nagad', 'NAGAD', const Color(0xFFF7921E)),
              const SizedBox(width: 8),
              _buildTypeChip('Bank', 'BANK', primaryColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Account Label (e.g. Personal bKash, Merchant)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _field1Controller,
            keyboardType: _method == 'BANK' ? TextInputType.text : TextInputType.phone,
            decoration: InputDecoration(
              labelText: field1Label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _field2Controller,
            decoration: InputDecoration(
              labelText: field2Label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            text: 'Save & Verify Account',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value, Color color) {
    final selected = _method == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.lightTextPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _method = value);
      },
    );
  }

  Future<void> _save() async {
    final details = <String, dynamic>{
      if (_method == 'BANK') 'bank_name': _field1Controller.text.trim(),
      if (_method == 'BANK') 'account_number': _field2Controller.text.trim(),
      if (_method != 'BANK') 'wallet_number': _field1Controller.text.trim(),
      if (_field2Controller.text.trim().isNotEmpty) 'name': _field2Controller.text.trim(),
    };

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final vendorProvider = context.read<VendorProvider>();

    setState(() => _saving = true);
    final ok = await vendorProvider.createPayoutMethod(
      method: _method,
      label: _labelController.text.trim(),
      details: details,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Payout account saved and verified.'), behavior: SnackBarBehavior.floating),
      );
    } else {
      final error = vendorProvider.walletError;
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to save account.'), backgroundColor: AppColors.error),
      );
    }
  }
}

// ── 6. Payout Request History Tile ──
class _PayoutRequestTile extends StatelessWidget {
  final VendorPayoutRequestModel payout;

  const _PayoutRequestTile({required this.payout});

  @override
  Widget build(BuildContext context) {
    final isPaid = payout.status == 'PAID';
    final isRejected = payout.status == 'REJECTED';
    final isProcessing = payout.status == 'PROCESSING';

    final Color statusColor = isPaid
        ? AppColors.success
        : (isRejected ? AppColors.error : (isProcessing ? Colors.blue : AppColors.warning));

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      payout.disbursalChannel.isNotEmpty ? payout.disbursalChannel : 'BANK',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  if (payout.isAutomated) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Auto-Payout',
                        style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withAlpha(60)),
                ),
                child: Text(
                  payout.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '৳${payout.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (payout.gatewayReference != null && payout.gatewayReference!.isNotEmpty)
                Text(
                  'Ref: ${payout.gatewayReference}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                ),
            ],
          ),
          if (payout.failureReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${payout.failureReason}',
              style: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ],
          if (payout.status == 'REQUESTED' || payout.status == 'APPROVED') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.flash_on, size: 14),
                label: const Text('Disburse Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final ok = await context.read<VendorProvider>().disbursePayout(payout.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Payout disbursed successfully!' : 'Disbursal failed.'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 7. Ledger Entry Tile ──
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
            child: Icon(tileIcon, size: 18, color: typeColor),
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
                  style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isCredit ? '+' : '-'}৳${entry.amount.toStringAsFixed(2)}',
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
