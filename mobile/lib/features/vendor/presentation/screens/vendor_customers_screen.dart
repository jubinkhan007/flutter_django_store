import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../providers/vendor_provider.dart';

class VendorCustomersScreen extends StatefulWidget {
  const VendorCustomersScreen({super.key});

  @override
  State<VendorCustomersScreen> createState() => _VendorCustomersScreenState();
}

class _VendorCustomersScreenState extends State<VendorCustomersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Header ──
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'My Customers',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Loading & Error States ──
          Expanded(
            child: Consumer<VendorProvider>(
              builder: (context, vendor, _) {
                if (vendor.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                }

                if (vendor.error != null && vendor.customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          vendor.error!,
                          style: TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () => vendor.loadCustomers(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (vendor.customers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: AppColors.lightTextSecondary,
                          size: 48,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No customers yet',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          'Customers will appear here once they place an order.',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // ── Customer List ──
                return RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () => vendor.loadCustomers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: vendor.customers.length,
                    itemBuilder: (context, index) {
                      final customer = vendor.customers[index];
                      // Provide an avatar based on the first letter of their username
                      final initial = customer.username.isNotEmpty
                          ? customer.username[0].toUpperCase()
                          : '?';

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: AppSpacing.sm,
                        ),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(
                            AppRadius.md,
                          ),
                          border: Border.all(
                            color: AppColors.lightTextSecondary.withAlpha(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withAlpha(20),
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    customer.email,
                                    style: const TextStyle(
                                      color: AppColors.lightTextSecondary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${customer.totalSpend.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${customer.totalOrders} order${customer.totalOrders > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.lightTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
