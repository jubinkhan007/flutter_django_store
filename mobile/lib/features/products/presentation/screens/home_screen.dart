import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/theme/app_radius.dart';
import 'package:mobile/core/theme/app_gradients.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/cart/presentation/providers/cart_provider.dart';
import 'package:mobile/features/orders/presentation/providers/order_provider.dart';
import 'package:mobile/features/products/presentation/providers/product_provider.dart';
import 'package:mobile/features/products/presentation/widgets/product_card.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';
import 'package:mobile/features/cart/presentation/screens/cart_screen.dart';
import 'package:mobile/features/orders/presentation/screens/order_history_screen.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/auth/presentation/screens/profile_screen.dart';
import 'package:mobile/features/cms/data/models/cms_models.dart';
import 'package:mobile/features/cms/presentation/providers/cms_provider.dart';
import 'package:mobile/features/home/presentation/providers/home_provider.dart';
import 'package:mobile/features/home/presentation/widgets/hero_banner_carousel.dart';
import 'package:mobile/features/home/presentation/widgets/flash_sale_row.dart';
import 'package:mobile/features/home/presentation/widgets/featured_section_row.dart';
import 'package:mobile/features/home/presentation/widgets/home_skeleton.dart';
import 'package:mobile/features/home/data/models/home_feed_model.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'dart:ui';
import 'package:mobile/core/services/analytics_service.dart';
import 'package:mobile/features/products/presentation/widgets/discovery_widgets.dart';

import 'package:mobile/features/products/presentation/widgets/search_overlay.dart';

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
      context.read<NotificationProvider>().refreshUnreadCount();
      context.read<CmsProvider>().loadBootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _ShopPage(),
      CartScreen(onOrderPlaced: () => setState(() => _currentIndex = 2)),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
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
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
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

class _ShopPage extends StatelessWidget {
  const _ShopPage();

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cmsProvider = context.watch<CmsProvider>();
    final cmsTopBanners = _mapCmsBanners(
      cmsProvider.bannersForPosition('HOME_TOP'),
    );
    final cmsMidBanners = _mapCmsBanners(
      cmsProvider.bannersForPosition('HOME_MID'),
    );
    final announcementEnabled = cmsProvider.boolSetting(
      'home_announcement_enabled',
    );
    final announcementText = cmsProvider.stringSetting('home_announcement_text');

    final hasQuery =
        (productProvider.searchQuery != null &&
            productProvider.searchQuery!.trim().isNotEmpty);
    final hasCategory = productProvider.selectedCategoryId != null;
    final hasActiveFilters =
        productProvider.minPrice != null ||
        productProvider.maxPrice != null ||
        (productProvider.sortBy != null && productProvider.sortBy != 'newest');
    final isShowingResults = hasQuery || hasCategory || hasActiveFilters;

    String resultsTitle() {
      final query = productProvider.searchQuery?.trim() ?? '';
      if (query.isNotEmpty) return 'Results for "$query"';
      if (hasCategory) {
        final selectedId = productProvider.selectedCategoryId;
        if (selectedId != null) {
          for (final c in productProvider.categories) {
            if (c.id == selectedId) return c.name;
          }
        }
        return 'Category results';
      }
      return 'Filtered results';
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<HomeProvider>().refresh(),
            context.read<ProductProvider>().loadProducts(),
            context.read<CmsProvider>().loadBootstrap(forceRefresh: true),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
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
                        Consumer<NotificationProvider>(
                          builder: (context, notifications, _) {
                            Widget icon = const Icon(Icons.notifications_none);
                            if (notifications.unreadCount > 0) {
                              icon = Badge(
                                label: Text('${notifications.unreadCount}'),
                                backgroundColor: AppColors.error,
                                child: icon,
                              );
                            }
                            return IconButton(
                              onPressed: () async {
                                await notifications.load();
                                if (context.mounted) {
                                  Navigator.pushNamed(
                                    context,
                                    '/notifications',
                                  );
                                }
                              },
                              icon: icon,
                              tooltip: 'Notifications',
                            );
                          },
                        ),
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
            ),
            SliverToBoxAdapter(
              child: SearchOverlay(
                onSearchCleared: () async {
                  context.read<ProductProvider>().setSearchQuery(null);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: productProvider.categories.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          children: [
                            _CategoryChip(
                              label: 'All',
                              isSelected: productProvider.selectedCategoryId ==
                                  null,
                              onTap: () =>
                                  context.read<ProductProvider>().selectCategory(
                                    null,
                                  ),
                            ),
                            ...productProvider.categories.map(
                              (cat) => _CategoryChip(
                                label: cat.name,
                                isSelected:
                                    productProvider.selectedCategoryId ==
                                    cat.id,
                                onTap: () => context
                                    .read<ProductProvider>()
                                    .selectCategory(cat.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (!isShowingResults &&
                announcementEnabled &&
                announcementText != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: _AnnouncementBanner(message: announcementText),
                ),
              ),
            if (!isShowingResults && cmsTopBanners.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: HeroBannerCarousel(banners: cmsTopBanners),
                ),
              ),
            if (!isShowingResults)
              Consumer<HomeProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.feed == null) {
                    return const SliverToBoxAdapter(child: HomeSkeleton());
                  }
                  if (provider.feed == null) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final section = provider.feed!.sections[index];
                      Widget child;
                      switch (section.type) {
                        case HomeSectionType.banners:
                          child = HeroBannerCarousel(
                            banners: (section as BannersSection).banners,
                          );
                          break;
                        case HomeSectionType.flashSale:
                          child = FlashSaleRow(
                            sale: (section as FlashSaleSection),
                            serverNow: provider.feed!.serverNow,
                          );
                          break;
                        case HomeSectionType.featuredRow:
                          child = FeaturedSectionRow(
                            section: (section as FeaturedRowSection),
                          );
                          break;
                        default:
                          child = const SizedBox.shrink();
                      }

                      return ImpressionOnce(
                        eventType: 'IMPRESSION',
                        source: 'HOME',
                        metadata: {
                          'section_type': section.type.name,
                          'position': index,
                        },
                        child: child,
                      );
                    }, childCount: provider.feed!.sections.length),
                  );
                },
              ),
            if (!isShowingResults && cmsMidBanners.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: HeroBannerCarousel(banners: cmsMidBanners),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  isShowingResults ? resultsTitle() : 'Recommended for You',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (productProvider.isLoading && productProvider.products.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (productProvider.error != null &&
                productProvider.products.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text('Could not load products'),
                      TextButton(
                        onPressed: () =>
                            context.read<ProductProvider>().loadProducts(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (productProvider.products.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    isShowingResults
                        ? 'No products match your filters'
                        : 'No products available',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = productProvider.products[index];
                    return ProductCard(
                      product: product,
                      onTap: () {
                        final query = productProvider.searchQuery?.trim() ?? '';
                        final source = query.isNotEmpty ? 'SEARCH' : 'HOME';
                        context.read<AnalyticsService>().logEvent(
                          eventType: 'CLICK',
                          source: source,
                          productId: product.id,
                          metadata: {
                            'position': index,
                            if (query.isNotEmpty) 'query': query,
                            if (productProvider.selectedCategoryId != null)
                              'category_id': productProvider.selectedCategoryId,
                          },
                        );
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
                        context.read<AnalyticsService>().logEvent(
                          eventType: 'ADD_TO_CART',
                          source: 'HOME',
                          productId: product.id,
                          metadata: {'position': index},
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            backgroundColor: Theme.of(context).primaryColor,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  }, childCount: productProvider.products.length),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom +
                    kBottomNavigationBarHeight +
                    AppSpacing.xl +
                    AppSpacing.md,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<BannerModel> _mapCmsBanners(List<CmsBanner> banners) {
  return banners
      .map(
        (banner) => BannerModel(
          id: banner.id,
          title: banner.title,
          subtitle: banner.subtitle,
          imageUrl: banner.imageUrl,
          linkType: banner.targetType,
          linkValue: banner.targetValue,
        ),
      )
      .toList();
}

class _AnnouncementBanner extends StatelessWidget {
  final String message;

  const _AnnouncementBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppGradients.lightPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
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
            gradient: isSelected ? AppGradients.lightPrimary : null,
            color: isSelected ? null : AppColors.lightSurface,
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
