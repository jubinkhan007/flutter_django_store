import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/return_provider.dart';
import 'return_detail_screen.dart';
import 'return_select_order_screen.dart';


class ReturnListScreen extends StatefulWidget {
  const ReturnListScreen({super.key});

  @override
  State<ReturnListScreen> createState() => _ReturnListScreenState();
}

class _ReturnListScreenState extends State<ReturnListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReturnProvider>().loadMyReturns();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Returns')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final submitted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ReturnSelectOrderScreen()),
          );
          if (submitted == true && context.mounted) {
            await context.read<ReturnProvider>().loadMyReturns();
          }
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Start return'),
      ),
      body: Consumer<ReturnProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.myReturns.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (provider.error != null && provider.myReturns.isEmpty) {
            return Center(
              child: Text(
                provider.error!,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }
          if (provider.myReturns.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                child: Text(
                  'No return requests yet.\nTap "Start return" to create one.',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () => provider.loadMyReturns(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: provider.myReturns.length,
              itemBuilder: (context, index) {
                final rr = provider.myReturns[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReturnDetailScreen(returnRequest: rr),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.assignment_return_outlined,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rr.rmaNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${rr.status} • ${rr.requestType} • ${rr.reason}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
