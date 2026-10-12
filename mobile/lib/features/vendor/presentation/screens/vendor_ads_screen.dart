import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../products/data/models/product_model.dart';
import '../../data/models/ad_campaign_model.dart';
import '../providers/vendor_ads_provider.dart';
import '../providers/vendor_provider.dart';

class VendorAdsScreen extends StatefulWidget {
  const VendorAdsScreen({super.key});

  @override
  State<VendorAdsScreen> createState() => _VendorAdsScreenState();
}

class _VendorAdsScreenState extends State<VendorAdsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorAdsProvider>().loadAdsData();
      final vendorProvider = context.read<VendorProvider>();
      if (vendorProvider.products.isEmpty) {
        vendorProvider.loadProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adsProvider = context.watch<VendorAdsProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        title: Text(
          'Sponsored Ads & PPC',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<VendorAdsProvider>().loadAdsData(),
        child: Builder(
          builder: (context) {
            if (adsProvider.isLoading && adsProvider.campaigns.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (adsProvider.error != null && adsProvider.campaigns.isEmpty) {
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
                          adsProvider.error!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          text: 'Retry',
                          onPressed: () =>
                              context.read<VendorAdsProvider>().loadAdsData(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final stats = adsProvider.stats;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // ── 1. Ad Balance & Top-up Card ──
                _AdBalanceCard(
                  stats: stats,
                  primaryColor: primaryColor,
                  onTopUpPressed: () => _showTopUpDialog(context, stats),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── 2. Performance Stats Overview ──
                _PerformanceStatsGrid(stats: stats),
                const SizedBox(height: AppSpacing.lg),

                // ── 3. Campaigns Header & Create Button ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Campaigns (${adsProvider.campaigns.length})',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCreateCampaignDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Campaign'),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── 4. Campaigns List or Empty State ──
                if (adsProvider.campaigns.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 64,
                          color: primaryColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No Boosted Listings Yet',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Promote your products to appear at the very top of search and category feeds.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateCampaignDialog(context),
                          icon: const Icon(Icons.rocket_launch, size: 18),
                          label: const Text('Create Your First Campaign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...adsProvider.campaigns.map(
                    (campaign) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _CampaignCard(
                        campaign: campaign,
                        primaryColor: primaryColor,
                        onToggleStatus: (active) {
                          adsProvider.toggleCampaignStatus(
                            campaign.id,
                            active,
                          );
                        },
                      ),
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

  void _showTopUpDialog(BuildContext context, AdStatsModel stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpBottomSheet(availableBalance: stats.availableBalance),
    );
  }

  void _showCreateCampaignDialog(BuildContext context) {
    final products = context.read<VendorProvider>().products;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCampaignBottomSheet(products: products),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET: Ad Balance & Top-Up Card
// ─────────────────────────────────────────────────────────────
class _AdBalanceCard extends StatelessWidget {
  final AdStatsModel stats;
  final Color primaryColor;
  final VoidCallback onTopUpPressed;

  const _AdBalanceCard({
    required this.stats,
    required this.primaryColor,
    required this.onTopUpPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'Ad Credits Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onTopUpPressed,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Top Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '৳${stats.adBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Available store earnings: ৳${stats.availableBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET: Performance Stats Grid
// ─────────────────────────────────────────────────────────────
class _PerformanceStatsGrid extends StatelessWidget {
  final AdStatsModel stats;

  const _PerformanceStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Total Ad Spend',
                value: '৳${stats.totalSpend.toStringAsFixed(2)}',
                icon: Icons.receipt_long_outlined,
                iconColor: Colors.blue,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Total Views',
                value: '${stats.totalImpressions}',
                icon: Icons.visibility_outlined,
                iconColor: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Total Clicks',
                value: '${stats.totalClicks}',
                icon: Icons.touch_app_outlined,
                iconColor: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                label: 'Average CTR',
                value: '${stats.avgCtr.toStringAsFixed(2)}%',
                icon: Icons.trending_up,
                iconColor: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET: Campaign Card
// ─────────────────────────────────────────────────────────────
class _CampaignCard extends StatelessWidget {
  final AdCampaignModel campaign;
  final Color primaryColor;
  final ValueChanged<bool> onToggleStatus;

  const _CampaignCard({
    required this.campaign,
    required this.primaryColor,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final product = campaign.productDetail;
    final isExhausted = campaign.isExhausted;
    final isActive = campaign.isActive;

    Color statusColor;
    String statusText = campaign.status;
    if (isActive) {
      statusColor = Colors.green;
      statusText = 'ACTIVE';
    } else if (isExhausted) {
      statusColor = Colors.red;
      statusText = 'EXHAUSTED';
    } else {
      statusColor = Colors.orange;
      statusText = 'PAUSED';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Product Info & Status / Switch ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: 50,
                  height: 50,
                  color: AppColors.lightBg,
                  child: product?.image != null
                      ? Image.network(
                          product!.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_outlined,
                            color: AppColors.lightTextSecondary,
                          ),
                        )
                      : const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.lightTextSecondary,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Title & Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product?.name ?? 'Product #${campaign.product}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '৳${product?.price.toStringAsFixed(2) ?? '0.00'}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge & Switch
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isExhausted)
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isActive,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: onToggleStatus,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Budget Progress Bar ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget Spent: ৳${campaign.budgetSpent.toStringAsFixed(2)} / ৳${campaign.budgetTotal.toStringAsFixed(2)}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(campaign.budgetProgress * 100).toInt()}%',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: campaign.budgetProgress,
                  minHeight: 6,
                  backgroundColor: AppColors.lightOutline.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isExhausted ? Colors.red : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Metrics Row: Views | Clicks | CTR | CPC ──
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.lightBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(label: 'Views', value: '${campaign.impressionsCount}'),
                _MiniDivider(),
                _MiniStat(label: 'Clicks', value: '${campaign.clicksCount}'),
                _MiniDivider(),
                _MiniStat(label: 'CTR', value: '${campaign.ctr}%'),
                _MiniDivider(),
                _MiniStat(
                  label: 'CPC',
                  value: '৳${campaign.costPerClick.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),

          // ── Keywords Tags if any ──
          if (campaign.keywords.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: campaign.keywords
                  .map(
                    (kw) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '#$kw',
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _MiniDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.lightOutline,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET: Top Up Ad Balance
// ─────────────────────────────────────────────────────────────
class _TopUpBottomSheet extends StatefulWidget {
  final double availableBalance;

  const _TopUpBottomSheet({required this.availableBalance});

  @override
  State<_TopUpBottomSheet> createState() => _TopUpBottomSheetState();
}

class _TopUpBottomSheetState extends State<_TopUpBottomSheet> {
  final _amountController = TextEditingController();
  final List<double> _quickAmounts = [100.0, 250.0, 500.0, 1000.0];
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() async {
    final rawText = _amountController.text.trim();
    final amount = double.tryParse(rawText);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }

    if (amount > widget.availableBalance) {
      setState(() => _error =
          'Amount exceeds available store earnings (৳${widget.availableBalance.toStringAsFixed(2)}).');
      return;
    }

    setState(() => _error = null);
    final provider = context.read<VendorAdsProvider>();
    final success = await provider.topUp(amount);

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added ৳$amount to Ad Balance!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      setState(() => _error = provider.error ?? 'Top up failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActionLoading = context.watch<VendorAdsProvider>().isActionLoading;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightOutline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Top Up Ad Credits',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Transfer funds directly from your store earnings into ad credits.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Available balance notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Available Earnings: ৳${widget.availableBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Quick preset chips
          Wrap(
            spacing: 8,
            children: _quickAmounts.map((preset) {
              return ActionChip(
                label: Text('৳${preset.toInt()}'),
                onPressed: () {
                  _amountController.text = preset.toStringAsFixed(0);
                  setState(() => _error = null);
                },
                backgroundColor: AppColors.lightBg,
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Custom Amount Field
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Top-up Amount (৳)',
              prefixText: '৳ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActionLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: isActionLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Confirm Transfer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET: Create Ad Campaign
// ─────────────────────────────────────────────────────────────
class _CreateCampaignBottomSheet extends StatefulWidget {
  final List<ProductModel> products;

  const _CreateCampaignBottomSheet({required this.products});

  @override
  State<_CreateCampaignBottomSheet> createState() =>
      _CreateCampaignBottomSheetState();
}

class _CreateCampaignBottomSheetState
    extends State<_CreateCampaignBottomSheet> {
  ProductModel? _selectedProduct;
  final _budgetController = TextEditingController(text: '100.00');
  final _dailyBudgetController = TextEditingController();
  final _cpcController = TextEditingController(text: '2.00');
  final _keywordsController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) {
      _selectedProduct = widget.products.first;
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _dailyBudgetController.dispose();
    _cpcController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_selectedProduct == null) {
      setState(() => _error = 'Please select a product.');
      return;
    }

    final budgetTotal = double.tryParse(_budgetController.text.trim());
    if (budgetTotal == null || budgetTotal <= 0) {
      setState(() => _error = 'Please enter a valid total budget.');
      return;
    }

    final cpc = double.tryParse(_cpcController.text.trim());
    if (cpc == null || cpc <= 0) {
      setState(() => _error = 'Please enter a valid Cost Per Click (CPC).');
      return;
    }

    if (budgetTotal < cpc) {
      setState(() => _error = 'Total budget must be at least CPC.');
      return;
    }

    double? dailyBudget;
    if (_dailyBudgetController.text.trim().isNotEmpty) {
      dailyBudget = double.tryParse(_dailyBudgetController.text.trim());
    }

    final rawKeywords = _keywordsController.text.trim();
    final keywords = rawKeywords.isNotEmpty
        ? rawKeywords
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty)
            .toList()
        : <String>[];

    setState(() => _error = null);
    final provider = context.read<VendorAdsProvider>();
    final success = await provider.createCampaign(
      productId: _selectedProduct!.id,
      budgetTotal: budgetTotal,
      dailyBudget: dailyBudget,
      costPerClick: cpc,
      keywords: keywords,
      targetCategoryIds: _selectedProduct!.categoryId != null
          ? [_selectedProduct!.categoryId!]
          : [],
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign created and boosted listing is live!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      setState(() => _error = provider.error ?? 'Failed to create campaign');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActionLoading = context.watch<VendorAdsProvider>().isActionLoading;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Boost Product Listing',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Featured at the top of category browsing & search feeds.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.error, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Product Picker ──
            Text(
              'Select Product',
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (widget.products.isEmpty)
              const Text(
                'No products available to promote. Add products first.',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              )
            else
              DropdownButtonFormField<ProductModel>(
                initialValue: _selectedProduct,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: widget.products.map((p) {
                  return DropdownMenuItem<ProductModel>(
                    value: p,
                    child: Text(
                      '${p.name} (৳${p.price.toStringAsFixed(2)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedProduct = val);
                },
              ),
            const SizedBox(height: AppSpacing.md),

            // ── Total Budget & CPC Row ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Budget (৳)',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _cpcController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cost Per Click (৳)',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Daily Budget (Optional) ──
            TextField(
              controller: _dailyBudgetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Daily Budget Limit (৳, optional)',
                prefixText: '৳ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Target Keywords ──
            TextField(
              controller: _keywordsController,
              decoration: InputDecoration(
                labelText: 'Target Keywords (comma-separated)',
                hintText: 'e.g. shoes, running, sneakers',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Launch Campaign Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isActionLoading ? null : _submit,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: isActionLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Launch Boost Campaign',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
