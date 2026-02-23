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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Shared Dependencies (DRY — created once, injected everywhere) ──
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(productRepository: productRepository),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(orderRepository: orderRepository),
        ),
      ],
      child: MaterialApp(
        title: 'ShopEase',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
