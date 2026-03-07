import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../../../addresses/presentation/screens/address_management_screen.dart';
import 'package:mobile/features/wishlist/presentation/screens/wishlist_screen.dart';
import '../../../coupons/presentation/screens/coupon_center_screen.dart';
import '../../../returns/presentation/screens/return_list_screen.dart';
import '../../../support/presentation/screens/support_center_screen.dart';
import '../../../crossborder/presentation/screens/cb_catalog_screen.dart';
import '../../../crossborder/presentation/screens/cb_my_orders_screen.dart';

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
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── User Info ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withAlpha((0.2 * 255).round()),
                      child: user.username.isNotEmpty
                          ? Text(
                              user.username[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : const Icon(Icons.person),
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
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withAlpha(
                                (0.1 * 255).round(),
                              ), // Changed withOpacity to withAlpha
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.isVendor ? 'Vendor' : 'Customer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Menu Options ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
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
                    const Divider(color: AppColors.lightSurface),
                    _MenuListItem(
                      icon: Icons.assignment_return_outlined,
                      title: 'Returns',
                      subtitle: 'Track or start a return (RMA)',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReturnListScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppColors.lightSurface),
                    _MenuListItem(
                      icon: Icons.local_offer_outlined,
                      title: 'Coupons',
                      subtitle: 'Apply coupons to your cart',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CouponCenterScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppColors.lightSurface),
                    _MenuListItem(
                      icon: Icons.flight_takeoff_outlined,
                      title: 'Shop Abroad',
                      subtitle: 'Order from international marketplaces',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CbCatalogScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppColors.lightSurface),
                    _MenuListItem(
                      icon: Icons.public_outlined,
                      title: 'International Orders',
                      subtitle: 'Track your cross-border purchases',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CbMyOrdersScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppColors.lightSurface),
                    _MenuListItem(
                      icon: Icons.support_agent_outlined,
                      title: 'Support Center',
                      subtitle: 'Get help and track disputes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportCenterScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AppColors.lightSurface),
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
                    const Divider(color: AppColors.lightSurface),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return _MenuListItem(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          subtitle: 'Toggle app theme',
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (value) {
                              themeProvider.setThemeMode(
                                value ? ThemeMode.dark : ThemeMode.light,
                              );
                            },
                          ),
                          onTap: () {},
                        );
                      },
                    ),
                    const Divider(color: AppColors.lightSurface),
                    _MenuListItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      iconColor: AppColors.error,
                      textColor: AppColors.error,
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
  final Widget? trailing;

  const _MenuListItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.lightTextPrimary),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.lightTextSecondary,
                fontSize: 13,
              ),
            )
          : null,
      trailing:
          trailing ??
          const Icon(Icons.chevron_right, color: AppColors.lightTextSecondary),
      onTap: onTap,
    );
  }
}
