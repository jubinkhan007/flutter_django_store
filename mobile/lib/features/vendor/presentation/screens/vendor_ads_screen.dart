import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class VendorAdsScreen extends StatelessWidget {
  const VendorAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boosted Listings (Ads)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.campaign,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Create campaigns, set daily budgets, and pay-per-click to feature your products across the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Waitlist joined!')),
                  );
                },
                icon: const Icon(Icons.mark_email_read),
                label: const Text('Join early access'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
