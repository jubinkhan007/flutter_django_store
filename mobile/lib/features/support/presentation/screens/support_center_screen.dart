import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../providers/support_provider.dart';
import 'create_ticket_screen.dart';
import 'ticket_chat_screen.dart';


class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  String _filter = 'OPEN';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().loadTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Center')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
          );
          if (!context.mounted) return;
          await context.read<SupportProvider>().loadTickets();
        },
        icon: const Icon(Icons.add),
        label: const Text('New ticket'),
      ),
      body: Consumer<SupportProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.tickets.isEmpty) {
            return const AppLoadingState(message: 'Loading tickets...');
          }

          if (provider.error != null && provider.tickets.isEmpty) {
            return AppErrorState(
              title: 'Support Error',
              message: provider.error ?? 'Failed to load tickets',
              onRetry: () => provider.loadTickets(status: _filter),
            );
          }

          final tickets = provider.tickets;
          final filtered = tickets.where((t) {
            if (_filter == 'OPEN') return t.status == 'OPEN';
            if (_filter == 'PENDING') return t.status.startsWith('PENDING');
            if (_filter == 'RESOLVED') {
              return t.status == 'RESOLVED' || t.status == 'CLOSED';
            }
            return true;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Open',
                      selected: _filter == 'OPEN',
                      onTap: () {
                        setState(() => _filter = 'OPEN');
                        provider.loadTickets();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      selected: _filter == 'PENDING',
                      onTap: () {
                        setState(() => _filter = 'PENDING');
                        provider.loadTickets();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Resolved',
                      selected: _filter == 'RESOLVED',
                      onTap: () {
                        setState(() => _filter = 'RESOLVED');
                        provider.loadTickets();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.loadTickets(),
                  child: filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            AppEmptyState(
                              icon: Icons.support_agent,
                              title: 'No tickets',
                              message: 'You have no tickets in this filter.',
                            )
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final t = filtered[index];
                            return Material(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await provider.openTicket(t.id);
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TicketChatScreen(
                                        ticketId: t.id,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      _StatusPill(status: t.status),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.ticketNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              t.subject,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.lightTextSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _timeAgo(t.lastActivityAt),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (t.isOverdueFirstResponse ||
                                          t.isOverdueResolution)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            color: AppColors.warning,
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

  static String _timeAgo(DateTime dt) {
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
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}


class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'OPEN':
        bg = AppColors.lightPrimary.withAlpha((0.12 * 255).round());
        fg = AppColors.lightPrimary;
        break;
      case 'RESOLVED':
      case 'CLOSED':
        bg = AppColors.success.withAlpha((0.12 * 255).round());
        fg = AppColors.success;
        break;
      default:
        bg = AppColors.warning.withAlpha((0.12 * 255).round());
        fg = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
