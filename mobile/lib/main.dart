import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Core
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/storage/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/analytics_service.dart';

// Auth
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'features/auth/presentation/screens/login_screen.dart';

// Products
import 'features/products/data/repositories/product_repository_impl.dart';
import 'features/products/data/repositories/discovery_repository_impl.dart';
import 'features/products/domain/repositories/product_repository.dart';
import 'features/products/domain/repositories/discovery_repository.dart';
import 'features/products/presentation/providers/product_provider.dart';
import 'features/products/presentation/screens/home_screen.dart';

// Cart
import 'features/cart/presentation/providers/cart_provider.dart';

// Orders
import 'features/orders/data/repositories/order_repository.dart';
import 'features/orders/presentation/providers/order_provider.dart';

// Vendor
import 'features/vendor/data/repositories/vendor_repository.dart';
import 'features/vendor/presentation/providers/vendor_provider.dart';
import 'features/vendor/presentation/screens/vendor_dashboard_screen.dart';
import 'features/vendor/presentation/screens/vendor_onboarding_screen.dart';
import 'features/vendor/presentation/screens/vendor_add_product_screen.dart';
import 'features/vendor/presentation/screens/vendor_wallet_screen.dart';

// Addresses
import 'features/addresses/data/repositories/address_repository.dart';
import 'features/addresses/presentation/providers/address_provider.dart';

// Reviews
import 'features/reviews/data/repositories/review_repository.dart';
import 'features/reviews/presentation/providers/review_provider.dart';

// Wishlist
import 'features/wishlist/data/repositories/wishlist_repository.dart';
import 'features/wishlist/presentation/providers/wishlist_provider.dart';

// Returns / RMA
import 'features/returns/data/repositories/return_repository.dart';
import 'features/returns/presentation/providers/return_provider.dart';

// Coupons (Customer)
import 'features/coupons/data/repositories/coupon_repository.dart';
import 'features/coupons/presentation/providers/coupon_provider.dart';

// Home Feed
import 'features/home/data/repositories/home_repository.dart';
import 'features/home/presentation/providers/home_provider.dart';

// Notifications
import 'features/notifications/data/repositories/notification_repository.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/notifications/presentation/screens/notification_screen.dart';

// Support
import 'features/support/data/repositories/support_repository.dart';
import 'features/support/presentation/providers/support_provider.dart';
import 'features/support/presentation/screens/support_center_screen.dart';

// Logistics
import 'features/logistics/data/repositories/logistics_repository.dart';

// Cross-Border
import 'features/crossborder/data/repositories/crossborder_repository.dart';
import 'features/crossborder/presentation/providers/crossborder_provider.dart';
import 'features/crossborder/presentation/screens/cb_catalog_screen.dart';
import 'features/crossborder/presentation/screens/cb_my_orders_screen.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/navigation/app_navigator.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set transparent status bar globally
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();
  final themeProvider = ThemeProvider(prefs);

  // ── Shared Dependencies (created once for the app lifetime) ──
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final sessionStorage = SessionStorage();
  final analyticsService = AnalyticsService(
    apiClient: apiClient,
    sessionStorage: sessionStorage,
  );

  // ── Repository Instances ──
  final AuthRepository authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );

  // We need AuthProvider early to wire up the global unauthenticated logout callback.
  final authProvider = AuthProvider(authRepository: authRepository);

  apiClient.onUnauthenticated = () {
    // 1. Log out locally
    authProvider.logout();

    // 2. Try to show a snackbar using the global navigator key
    final context = appNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  };

  final ProductRepository productRepository = ProductRepositoryImpl(
    apiClient: apiClient,
  );
  final DiscoveryRepository discoveryRepository = DiscoveryRepositoryImpl(
    apiClient: apiClient,
  );
  final orderRepository = OrderRepository(apiClient: apiClient);
  final vendorRepository = VendorRepository(apiClient: apiClient);
  final addressRepository = AddressRepository(apiClient: apiClient);
  final reviewRepository = ReviewRepository(apiClient: apiClient);
  final wishlistRepository = WishlistRepository(apiClient: apiClient);
  final returnRepository = ReturnRepository(apiClient: apiClient);
  final couponRepository = CouponRepository(apiClient: apiClient);
  final homeRepository = HomeRepository(apiClient: apiClient);
  final notificationRepository = NotificationRepository(apiClient: apiClient);
  final supportRepository = SupportRepository(apiClient: apiClient);
  final logisticsRepository = LogisticsRepository(apiClient: apiClient);
  final crossBorderRepository = CrossBorderRepository(apiClient: apiClient);

  runApp(
    MyApp(
      themeProvider: themeProvider,
      authProvider: authProvider,
      analyticsService: analyticsService,
      productRepository: productRepository,
      discoveryRepository: discoveryRepository,
      orderRepository: orderRepository,
      vendorRepository: vendorRepository,
      addressRepository: addressRepository,
      reviewRepository: reviewRepository,
      wishlistRepository: wishlistRepository,
      returnRepository: returnRepository,
      couponRepository: couponRepository,
      homeRepository: homeRepository,
      notificationRepository: notificationRepository,
      supportRepository: supportRepository,
      logisticsRepository: logisticsRepository,
      crossBorderRepository: crossBorderRepository,
    ),
  );
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  final AnalyticsService analyticsService;
  final ProductRepository productRepository;
  final DiscoveryRepository discoveryRepository;
  final OrderRepository orderRepository;
  final VendorRepository vendorRepository;
  final AddressRepository addressRepository;
  final ReviewRepository reviewRepository;
  final WishlistRepository wishlistRepository;
  final ReturnRepository returnRepository;
  final CouponRepository couponRepository;
  final HomeRepository homeRepository;
  final NotificationRepository notificationRepository;
  final SupportRepository supportRepository;
  final LogisticsRepository logisticsRepository;
  final CrossBorderRepository crossBorderRepository;

  const MyApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
    required this.analyticsService,
    required this.productRepository,
    required this.discoveryRepository,
    required this.orderRepository,
    required this.vendorRepository,
    required this.addressRepository,
    required this.reviewRepository,
    required this.wishlistRepository,
    required this.returnRepository,
    required this.couponRepository,
    required this.homeRepository,
    required this.notificationRepository,
    required this.supportRepository,
    required this.logisticsRepository,
    required this.crossBorderRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        Provider<AnalyticsService>.value(value: analyticsService),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepository: productRepository),
        ),
        Provider<DiscoveryRepository>.value(value: discoveryRepository),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider<OrderRepository>.value(value: orderRepository),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepository: orderRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => VendorProvider(vendorRepository: vendorRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AddressProvider(addressRepository: addressRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewProvider(repository: reviewRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              WishlistProvider(wishlistRepository: wishlistRepository)
                ..loadWishlist(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReturnProvider(repository: returnRepository),
        ),
        Provider<ReturnRepository>.value(value: returnRepository),
        ChangeNotifierProvider(
          create: (_) => CouponProvider(repository: couponRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              HomeProvider(homeRepository: homeRepository)..loadFeed(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              NotificationProvider(repository: notificationRepository)
                ..refreshUnreadCount(),
        ),
        Provider<NotificationRepository>.value(value: notificationRepository),
        ChangeNotifierProvider(
          create: (_) => SupportProvider(repository: supportRepository),
        ),
        Provider<SupportRepository>.value(value: supportRepository),
        Provider<LogisticsRepository>.value(value: logisticsRepository),
        ChangeNotifierProvider(
          create: (_) => CrossBorderProvider(repository: crossBorderRepository),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: theme.themeMode == ThemeMode.dark
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                  ),
            child: MaterialApp(
              title: 'ShopEase',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: theme.themeMode,
              navigatorKey: appNavigatorKey,
              home: const AuthGate(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/home': (context) => const HomeScreen(),
                '/vendor': (context) => const VendorDashboardScreen(),
                '/vendor/onboarding': (context) =>
                    const VendorOnboardingScreen(),
                '/vendor/add-product': (context) =>
                    const VendorAddProductScreen(),
                '/vendor/wallet': (context) => const VendorWalletScreen(),
                '/notifications': (context) => const NotificationScreen(),
                '/support': (context) => const SupportCenterScreen(),
                '/crossborder': (context) => const CbCatalogScreen(),
                '/crossborder/orders': (context) => const CbMyOrdersScreen(),
              },
            ),
          );
        },
      ),
    );
  }
}
