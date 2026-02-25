import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/products/presentation/screens/home_screen.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/products/data/repositories/product_repository_impl.dart';
import 'package:mobile/features/orders/data/repositories/order_repository.dart';
import 'package:mobile/features/vendor/data/repositories/vendor_repository.dart';
import 'package:mobile/features/addresses/data/repositories/address_repository.dart';
import 'package:mobile/features/reviews/data/repositories/review_repository.dart';
import 'package:mobile/features/wishlist/data/repositories/wishlist_repository.dart';
import 'package:mobile/features/returns/data/repositories/return_repository.dart';
import 'package:mobile/features/coupons/data/repositories/coupon_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/core/providers/theme_provider.dart';
import 'package:mobile/features/home/data/repositories/home_repository.dart';

void main() {
  testWidgets('Boots to login when logged out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);

    final authRepo = AuthRepositoryImpl(
      apiClient: apiClient,
      tokenStorage: tokenStorage,
    );
    final authProvider = AuthProvider(authRepository: authRepo);
    final productRepo = ProductRepositoryImpl(apiClient: apiClient);
    final orderRepo = OrderRepository(apiClient: apiClient);
    final vendorRepo = VendorRepository(apiClient: apiClient);
    final addressRepo = AddressRepository(apiClient: apiClient);
    final reviewRepo = ReviewRepository(apiClient: apiClient);
    final wishlistRepo = WishlistRepository(apiClient: apiClient);
    final returnRepo = ReturnRepository(apiClient: apiClient);
    final couponRepo = CouponRepository(apiClient: apiClient);
    final homeRepo = HomeRepository(apiClient: apiClient);

    final prefs = await SharedPreferences.getInstance();
    final themeProvider = ThemeProvider(prefs);

    await tester.pumpWidget(
      MyApp(
        themeProvider: themeProvider,
        authProvider: authProvider,
        productRepository: productRepo,
        orderRepository: orderRepo,
        vendorRepository: vendorRepo,
        addressRepository: addressRepo,
        reviewRepository: reviewRepo,
        wishlistRepository: wishlistRepo,
        returnRepository: returnRepo,
        couponRepository: couponRepo,
        homeRepository: homeRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Boots to home when tokens exist', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'jwt_access_token': 'not.a.real.jwt',
      'jwt_refresh_token': 'not.a.real.jwt',
      'user_type': 'CUSTOMER',
      'user_email': 'test@example.com',
    });

    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);

    final authRepo = AuthRepositoryImpl(
      apiClient: apiClient,
      tokenStorage: tokenStorage,
    );
    final authProvider = AuthProvider(authRepository: authRepo);
    final productRepo = ProductRepositoryImpl(apiClient: apiClient);
    final orderRepo = OrderRepository(apiClient: apiClient);
    final vendorRepo = VendorRepository(apiClient: apiClient);
    final addressRepo = AddressRepository(apiClient: apiClient);
    final reviewRepo = ReviewRepository(apiClient: apiClient);
    final wishlistRepo = WishlistRepository(apiClient: apiClient);
    final returnRepo = ReturnRepository(apiClient: apiClient);
    final couponRepo = CouponRepository(apiClient: apiClient);
    final homeRepo = HomeRepository(apiClient: apiClient);

    final prefs = await SharedPreferences.getInstance();
    final themeProvider = ThemeProvider(prefs);

    await tester.pumpWidget(
      MyApp(
        themeProvider: themeProvider,
        authProvider: authProvider,
        productRepository: productRepo,
        orderRepository: orderRepo,
        vendorRepository: vendorRepo,
        addressRepository: addressRepo,
        reviewRepository: reviewRepo,
        wishlistRepository: wishlistRepo,
        returnRepository: returnRepo,
        couponRepository: couponRepo,
        homeRepository: homeRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
