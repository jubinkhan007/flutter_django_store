import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../addresses/presentation/screens/address_management_screen.dart';
import 'package:mobile/features/wishlist/presentation/screens/wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          return Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Row(
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── User Info ──
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                ),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                      child: Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.isVendor ? 'Vendor' : 'Customer',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // ── Menu Options ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                  ),
                  children: [
                    _MenuListItem(
                      icon: Icons.favorite_border,
                      title: 'Saved Items',
                      subtitle: 'Your wishlisted products',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppTheme.surfaceLight),
                    _MenuListItem(
                      icon: Icons.location_on_outlined,
                      title: 'My Addresses',
                      subtitle: 'Manage delivery addresses',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddressManagementScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppTheme.surfaceLight),
                    _MenuListItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      iconColor: AppTheme.error,
                      textColor: AppTheme.error,
                      onTap: () {
                        context.read<AuthProvider>().logout();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _MenuListItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.textPrimary),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }
}
