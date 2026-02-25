import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../orders/presentation/screens/order_history_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import 'dart:ui';

import '../widgets/search_filter_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load products and categories when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<ProductProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _ShopPage(),
      CartScreen(onCheckoutComplete: () => setState(() => _currentIndex = 2)),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      // Extend body to allow content to slide under the floating nav bar
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.lightSurface.withAlpha((0.8 * 255).round())
                : AppColors.lightSurface.withAlpha((0.9 * 255).round()),
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppTheme.softShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavBarItem(
                      icon: Icons.storefront_outlined,
                      activeIcon: Icons.storefront,
                      label: 'Shop',
                      isSelected: _currentIndex == 0,
                      onTap: () => setState(() => _currentIndex = 0),
                    ),
                    Consumer<CartProvider>(
                      builder: (context, cart, child) {
                        return _NavBarItem(
                          icon: Icons.shopping_cart_outlined,
                          activeIcon: Icons.shopping_cart,
                          label: 'Cart',
                          isSelected: _currentIndex == 1,
                          badgeCount: cart.itemCount,
                          onTap: () => setState(() => _currentIndex = 1),
                        );
                      },
                    ),
                    _NavBarItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long,
                      label: 'Orders',
                      isSelected: _currentIndex == 2,
                      onTap: () {
                        setState(() => _currentIndex = 2);
                        context.read<OrderProvider>().loadOrdersWithLoading(
                          showLoading: false,
                        );
                      },
                    ),
                    _NavBarItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Profile',
                      isSelected: _currentIndex == 3,
                      onTap: () => setState(() => _currentIndex = 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Theme.of(context).primaryColor
        : AppColors.lightTextSecondary;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : icon,
      color: color,
      size: 24,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: AppColors.error,
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The main shop/browse page within the home screen.
class _ShopPage extends StatelessWidget {
  const _ShopPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ── Top Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lightTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Find amazing products',
                      style: TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Vendor switch (only visible to vendors)
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.user != null && auth.user!.isVendor) {
                          return IconButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                '/vendor',
                              );
                            },
                            icon: const Icon(Icons.dashboard_outlined),
                            tooltip: 'Vendor Dashboard',
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // Vendor onboarding (for customers who want to become vendors)
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.user != null && auth.user!.isCustomer) {
                          return IconButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/vendor/onboarding',
                              );
                            },
                            icon: const Icon(Icons.store_outlined),
                            tooltip: 'Become a Vendor',
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Search & Filter Bar ──
          const SearchFilterBar(),
          const SizedBox(height: AppSpacing.xs),

          // ── Category Chips ──
          Consumer<ProductProvider>(
            builder: (context, provider, _) {
              if (provider.categories.isEmpty) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      isSelected: provider.selectedCategoryId == null,
                      onTap: () => provider.selectCategory(null),
                    ),
                    ...provider.categories.map(
                      (cat) => _CategoryChip(
                        label: cat.name,
                        isSelected: provider.selectedCategoryId == cat.id,
                        onTap: () => provider.selectCategory(cat.id),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Product Grid ──
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: AppColors.lightTextSecondary,
                          size: 48,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Could not load products',
                          style: const TextStyle(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () => provider.loadProducts(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.products.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.lightTextSecondary,
                          size: 48,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No products available',
                          style: TextStyle(color: AppColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () => provider.loadProducts(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: provider.products.length,
                    itemBuilder: (context, index) {
                      final product = provider.products[index];
                      return ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(product: product),
                            ),
                          );
                        },
                        onAddToCart: () {
                          context.read<CartProvider>().addToCart(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} added to cart'),
                              backgroundColor: Theme.of(context).primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient:
                isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? AppGradients.darkPrimary
                        : AppGradients.lightPrimary)
                    : null,
            color: isSelected ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.lightTextSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
