import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../models/loyalty_account_model.dart';
import '../models/loyalty_transaction_model.dart';
import '../providers/loyalty_provider.dart';

class LoyaltyDashboardScreen extends StatefulWidget {
  const LoyaltyDashboardScreen({super.key});

  @override
  State<LoyaltyDashboardScreen> createState() => _LoyaltyDashboardScreenState();
}

class _LoyaltyDashboardScreenState extends State<LoyaltyDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LoyaltyProvider>();
      provider.fetchSummary();
      provider.fetchTransactions();
    });
  }

  Color _getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'PLATINUM':
        return const Color(0xFF6366F1); // Indigo / Platinum
      case 'GOLD':
        return const Color(0xFFEAB308); // Radiant Gold
      case 'SILVER':
        return const Color(0xFF64748B); // Sleek Silver
      case 'BRONZE':
      default:
        return const Color(0xFFD97706); // Warm Bronze / Amber
    }
  }

  LinearGradient _getTierGradient(String tier) {
    switch (tier.toUpperCase()) {
      case 'PLATINUM':
        return const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'GOLD':
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'SILVER':
        return const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF94A3B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'BRONZE':
      default:
        return const LinearGradient(
          colors: [Color(0xFF92400E), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoyaltyProvider>();
    final account = provider.account;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards & Loyalty'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: provider.isLoading && account == null
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: () => provider.refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                provider.error!,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Hero Tier Card ──
                    if (account != null)
                      _buildTierHeroCard(account)
                    else
                      _buildDefaultHeroCard(),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Tier Progress Card ──
                    if (account != null && account.nextTierInfo.nextTier != null)
                      _buildProgressCard(account.nextTierInfo),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Loyalty Perks & Rules ──
                    _buildPerksSection(account?.tierMultiplier ?? 1.0),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Activity / Ledger ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Points Activity',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.lightTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${provider.transactions.length} entries',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    if (provider.isLoadingTransactions &&
                        provider.transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (provider.transactions.isEmpty)
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.loyalty_outlined,
                                size: 48,
                                color: AppColors.lightMuted,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'No points activity yet',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Make your first purchase to start earning rewards!',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.lightMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.transactions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final tx = provider.transactions[index];
                          return _buildTransactionCard(tx);
                        },
                      ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTierHeroCard(LoyaltyAccountModel account) {
    final gradient = _getTierGradient(account.tier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withAlpha(75),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(100)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${account.tier.toUpperCase()} MEMBER',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${account.tierMultiplier}x Points Multiplier',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Available Points',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${account.pointsBalance}',
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'pts',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.savings_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Value: ৳${account.pointsValueBdt.toStringAsFixed(2)} off next order',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
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

  Widget _buildDefaultHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lightPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BRONZE MEMBER',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '0 pts',
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(NextTierInfo nextTier) {
    final nextColor = _getTierColor(nextTier.nextTier ?? 'SILVER');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next Tier: ${nextTier.nextTier?.toUpperCase()}',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(nextTier.progressRatio * 100).toInt()}%',
                style: AppTextStyles.labelLarge.copyWith(
                  color: nextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nextTier.progressRatio.clamp(0.0, 1.0),
              backgroundColor: AppColors.lightOutline,
              valueColor: AlwaysStoppedAnimation<Color>(nextColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Earn ${nextTier.pointsNeeded} more points to reach ${nextTier.nextTier} status!',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerksSection(double currentMultiplier) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program Benefits',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPerkItem(
            icon: Icons.payments_outlined,
            title: 'Earn Points on Purchases',
            subtitle: 'Get 1 point for every ৳10 spent (boosted by ${currentMultiplier}x for your tier)',
          ),
          const Divider(height: 20),
          _buildPerkItem(
            icon: Icons.redeem_outlined,
            title: 'Instant Checkout Discount',
            subtitle: 'Redeem 10 points for ৳1.00 instant store credit at checkout',
          ),
          const Divider(height: 20),
          _buildPerkItem(
            icon: Icons.auto_awesome_outlined,
            title: 'Tier Multipliers',
            subtitle: 'Bronze: 1.0x • Silver: 1.2x • Gold: 1.5x • Platinum: 2.0x',
          ),
        ],
      ),
    );
  }

  Widget _buildPerkItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.lightPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                ),
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
      ],
    );
  }

  Widget _buildTransactionCard(LoyaltyTransactionModel tx) {
    final isPositive = tx.points > 0;
    final color = tx.isRefund
        ? AppColors.info
        : isPositive
            ? AppColors.success
            : AppColors.warning;

    final icon = tx.isRefund
        ? Icons.replay
        : isPositive
            ? Icons.arrow_downward
            : Icons.arrow_upward;

    final formattedDate =
        '${tx.createdAt.year}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.day.toString().padLeft(2, '0')}';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty
                      ? tx.description
                      : tx.transactionType,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${tx.points} pts',
                style: AppTextStyles.labelLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal: ${tx.balanceAfter}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
