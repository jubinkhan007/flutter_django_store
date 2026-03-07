import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../providers/vendor_provider.dart';

class VendorAnalyticsScreen extends StatefulWidget {
  const VendorAnalyticsScreen({super.key});

  @override
  State<VendorAnalyticsScreen> createState() => _VendorAnalyticsScreenState();
}

class _VendorAnalyticsScreenState extends State<VendorAnalyticsScreen> {
  int _days = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadAnalyticsData(days: _days);
    });
  }

  void _onDaysChanged(int days) {
    setState(() => _days = days);
    context.read<VendorProvider>().loadAnalyticsData(days: _days);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance & Analytics')),
      body: Consumer<VendorProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.productAnalytics.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.productAnalytics.isEmpty) {
            return Center(
              child: Text(
                provider.error!,
                style: TextStyle(color: AppColors.error),
              ),
            );
          }

          final scorecard = provider.slaScorecard;
          final products = provider.productAnalytics;

          return RefreshIndicator(
            onRefresh: () => provider.loadAnalyticsData(days: _days),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _buildSlaScorecard(scorecard),
                const SizedBox(height: AppSpacing.xl),
                _buildTimeFilter(),
                const SizedBox(height: AppSpacing.md),
                _buildProductFunnels(products),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Product Performance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.lightTextPrimary,
          ),
        ),
        DropdownButton<int>(
          value: _days,
          items: const [
            DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
            DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
            DropdownMenuItem(value: 90, child: Text('Last 90 Days')),
          ],
          onChanged: (v) {
            if (v != null) _onDaysChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildSlaScorecard(Map<String, dynamic>? scorecard) {
    if (scorecard == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SLA Scorecard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                title: 'Cancel Rate',
                value:
                    '${(scorecard['cancellation_rate'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                isWarning: (scorecard['cancellation_rate'] ?? 0) > 5,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                title: 'Late Ship',
                value:
                    '${(scorecard['late_shipment_rate'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                isWarning: (scorecard['late_shipment_rate'] ?? 0) > 5,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                title: 'Returns',
                value:
                    '${(scorecard['returns_rate'] as num?)?.toStringAsFixed(1) ?? '0.0'}%',
                isWarning: (scorecard['returns_rate'] ?? 0) > 10,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricTile(
                title: 'Avg Handling',
                value:
                    '${(scorecard['avg_handling_time_days'] as num?)?.toStringAsFixed(1) ?? '0'} d',
                isWarning: (scorecard['avg_handling_time_days'] ?? 0) > 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductFunnels(List<dynamic> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No product performance data available yet.',
            style: TextStyle(color: AppColors.lightTextSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final p = products[index];
        final funnel = p['funnel'] ?? {};
        final metrics = p['metrics'] ?? {};
        final sponsored = p['sponsored'] ?? {};

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.grey.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p['product_name'] ?? 'Product',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FunnelStep(
                    label: 'Views',
                    value: '${funnel['impressions'] ?? 0}',
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey,
                  ),
                  _FunnelStep(
                    label: 'Clicks',
                    value: '${funnel['clicks'] ?? 0}',
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey,
                  ),
                  _FunnelStep(label: 'Carts', value: '${funnel['carts'] ?? 0}'),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey,
                  ),
                  _FunnelStep(
                    label: 'Sales',
                    value: '${funnel['purchases'] ?? 0}',
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    'CTR: ${metrics['ctr_percentage']}%',
                    style: const TextStyle(
                      color: AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'CVR: ${metrics['cvr_percentage']}%',
                    style: const TextStyle(
                      color: AppColors.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Rev: \$${metrics['revenue']}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if ((sponsored['clicks'] ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sponsored: ${sponsored['impressions']} views, ${sponsored['clicks']} clicks',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final bool isWarning;

  const _MetricTile({
    required this.title,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.error.withAlpha(20)
            : AppColors.success.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isWarning
              ? AppColors.error.withAlpha(100)
              : AppColors.success.withAlpha(100),
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isWarning ? AppColors.error : AppColors.success,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isWarning ? AppColors.error : AppColors.success,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelStep extends StatelessWidget {
  final String label;
  final String value;

  const _FunnelStep({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
