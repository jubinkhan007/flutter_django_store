import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../cms/data/models/cms_models.dart';
import '../../../cms/presentation/providers/cms_provider.dart';
import '../../../cms/presentation/screens/cms_page_screen.dart';
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
    final cmsProvider = context.watch<CmsProvider>();
    final supportLinks = _buildCmsSupportLinks(context, cmsProvider);
    final legalLinks = _buildCmsPageLinks(cmsProvider.bootstrap);

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
                              ),
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
                    ...supportLinks,
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
                    ...legalLinks,
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return _MenuListItem(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Mode',
                          subtitle: 'Toggle app theme',
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            activeThumbColor: Theme.of(context).primaryColor,
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

List<Widget> _buildCmsSupportLinks(BuildContext context, CmsProvider cmsProvider) {
  final items = <Widget>[];
  final email = cmsProvider.stringSetting('support_email');
  final phone = cmsProvider.stringSetting('support_phone');
  final whatsapp = cmsProvider.stringSetting('support_whatsapp');
  final whatsappUrl = cmsProvider.stringSetting('support_whatsapp_url');

  void addItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String rawUrl,
  }) {
    items.add(
      _MenuListItem(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () => _openExternalLink(context, rawUrl),
      ),
    );
    items.add(const Divider(color: AppColors.lightSurface));
  }

  if (email != null) {
    addItem(
      icon: Icons.email_outlined,
      title: 'Email Support',
      subtitle: email,
      rawUrl: 'mailto:$email',
    );
  }
  if (phone != null) {
    addItem(
      icon: Icons.phone_outlined,
      title: 'Call Support',
      subtitle: phone,
      rawUrl: 'tel:$phone',
    );
  }
  final whatsappDigits = whatsapp?.replaceAll(RegExp(r'[^0-9]'), '');
  final whatsappTarget = whatsappUrl ??
      ((whatsappDigits == null || whatsappDigits.isEmpty)
          ? null
          : 'https://wa.me/$whatsappDigits');
  if (whatsappTarget != null) {
    addItem(
      icon: Icons.chat_bubble_outline,
      title: 'WhatsApp Support',
      subtitle: whatsapp ?? 'Chat with support',
      rawUrl: whatsappTarget,
    );
  }

  return items;
}

List<Widget> _buildCmsPageLinks(CmsBootstrap? bootstrap) {
  if (bootstrap == null) return const [];

  const orderedTypes = [
    'ABOUT',
    'PRIVACY',
    'TERMS',
    'REFUND_POLICY',
  ];

  final items = <Widget>[];
  for (final pageType in orderedTypes) {
    final page = bootstrap.pageByType(pageType);
    if (page == null) {
      continue;
    }
    items.add(
      Builder(
        builder: (context) => _MenuListItem(
          icon: _pageIcon(page.pageType),
          title: page.title,
          subtitle: 'Read ${page.title}',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CmsPageScreen(
                  slug: page.slug,
                  titleOverride: page.title,
                ),
              ),
            );
          },
        ),
      ),
    );
    items.add(const Divider(color: AppColors.lightSurface));
  }
  return items;
}

IconData _pageIcon(String pageType) {
  switch (pageType) {
    case 'ABOUT':
      return Icons.info_outline;
    case 'PRIVACY':
      return Icons.lock_outline;
    case 'TERMS':
      return Icons.gavel_outlined;
    case 'REFUND_POLICY':
      return Icons.assignment_return_outlined;
    default:
      return Icons.description_outlined;
  }
}

Future<void> _openExternalLink(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) {
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this link.'),
        behavior: SnackBarBehavior.floating,
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
