import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/services/notification_service.dart';
import '../providers/notification_provider.dart';


class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  bool _matchesFilter(String type) {
    if (_filter == 'ALL') return true;
    if (_filter == 'ORDERS') return type.startsWith('ORDER_') || type == 'NEW_SUBORDER';
    if (_filter == 'PAYOUTS') return type.startsWith('PAYOUT_');
    if (_filter == 'REFUNDS') return type.startsWith('REFUND_');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await context.read<NotificationProvider>().markAllRead();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.items.isEmpty) {
            return const AppLoadingState(message: 'Loading notifications...');
          }

          if (provider.error != null && provider.items.isEmpty) {
            return AppErrorState(
              title: 'Notifications Error',
              message: provider.error ?? 'Failed to load notifications',
              onRetry: () => provider.load(),
            );
          }

          final items = provider.items.where((n) => _matchesFilter(n.type)).toList();
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              message: 'You’re all caught up.',
              buttonText: 'Refresh',
              onAction: () => provider.load(),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _filter == 'ALL',
                      onTap: () => setState(() => _filter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Orders',
                      isSelected: _filter == 'ORDERS',
                      onTap: () => setState(() => _filter = 'ORDERS'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Refunds',
                      isSelected: _filter == 'REFUNDS',
                      onTap: () => setState(() => _filter = 'REFUNDS'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Payouts',
                      isSelected: _filter == 'PAYOUTS',
                      onTap: () => setState(() => _filter = 'PAYOUTS'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.load();
                    await provider.refreshUnreadCount();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return Material(
                        color: n.isRead
                            ? Theme.of(context).cardColor
                            : Theme.of(context).primaryColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            if (!n.isRead) {
                              await provider.markRead(n.id);
                            }
                            if (!context.mounted) return;
                            await NotificationService.openDeeplink(context, n.deeplink);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 6, right: 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: n.isRead ? Colors.transparent : AppColors.lightPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (n.body.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          style: const TextStyle(
                                            color: AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTime(n.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}


class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}

