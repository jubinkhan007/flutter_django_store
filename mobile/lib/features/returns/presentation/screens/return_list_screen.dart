import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
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
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Start return'),
      ),
      body: Consumer<ReturnProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.myReturns.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }
          if (provider.error != null && provider.myReturns.isEmpty) {
            return Center(
              child: Text(
                provider.error!,
                style: TextStyle(color: AppColors.lightTextSecondary),
              ),
            );
          }
          if (provider.myReturns.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No return requests yet.\nTap "Start return" to create one.',
                  style: TextStyle(color: AppColors.lightTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: Theme.of(context).primaryColor,
            onRefresh: () => provider.loadMyReturns(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment_return_outlined,
                          color: Theme.of(context).primaryColor,
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
                                  color: AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${rr.status} • ${rr.requestType} • ${rr.reason}',
                                style: const TextStyle(
                                  color: AppColors.lightTextSecondary,
                                  fontSize: 12,
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
