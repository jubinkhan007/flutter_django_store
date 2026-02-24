import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';

// Auth
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'features/auth/presentation/screens/login_screen.dart';

// Products
import 'features/products/data/repositories/product_repository_impl.dart';
import 'features/products/domain/repositories/product_repository.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Shared Dependencies (created once for the app lifetime) ──
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);

  // ── Repository Instances ──
  final AuthRepository authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );
  final ProductRepository productRepository = ProductRepositoryImpl(
    apiClient: apiClient,
  );
  final orderRepository = OrderRepository(apiClient: apiClient);
  final vendorRepository = VendorRepository(apiClient: apiClient);
  final addressRepository = AddressRepository(apiClient: apiClient);
  final reviewRepository = ReviewRepository(apiClient: apiClient);
  final wishlistRepository = WishlistRepository(apiClient: apiClient);
  final returnRepository = ReturnRepository(apiClient: apiClient);
  final couponRepository = CouponRepository(apiClient: apiClient);

  runApp(
    MyApp(
      authRepository: authRepository,
      productRepository: productRepository,
      orderRepository: orderRepository,
      vendorRepository: vendorRepository,
      addressRepository: addressRepository,
      reviewRepository: reviewRepository,
      wishlistRepository: wishlistRepository,
      returnRepository: returnRepository,
      couponRepository: couponRepository,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ProductRepository productRepository;
  final OrderRepository orderRepository;
  final VendorRepository vendorRepository;
  final AddressRepository addressRepository;
  final ReviewRepository reviewRepository;
  final WishlistRepository wishlistRepository;
  final ReturnRepository returnRepository;
  final CouponRepository couponRepository;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.productRepository,
    required this.orderRepository,
    required this.vendorRepository,
    required this.addressRepository,
    required this.reviewRepository,
    required this.wishlistRepository,
    required this.returnRepository,
    required this.couponRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepository: productRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
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
        ChangeNotifierProvider(
          create: (_) => CouponProvider(repository: couponRepository),
        ),
      ],
      child: MaterialApp(
        title: 'ShopEase',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/vendor': (context) => const VendorDashboardScreen(),
          '/vendor/onboarding': (context) => const VendorOnboardingScreen(),
          '/vendor/add-product': (context) => const VendorAddProductScreen(),
        },
      ),
    );
  }
}
