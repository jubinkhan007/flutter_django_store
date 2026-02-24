import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/products/data/repositories/product_repository_impl.dart';
import 'package:mobile/features/orders/data/repositories/order_repository.dart';
import 'package:mobile/features/vendor/data/repositories/vendor_repository.dart';

void main() {
  testWidgets('Boots to login when logged out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final tokenStorage = TokenStorage();
    final apiClient = ApiClient(tokenStorage: tokenStorage);

    final authRepo = AuthRepositoryImpl(
      apiClient: apiClient,
      tokenStorage: tokenStorage,
    );
    final productRepo = ProductRepositoryImpl(apiClient: apiClient);
    final orderRepo = OrderRepository(apiClient: apiClient);
    final vendorRepo = VendorRepository(apiClient: apiClient);

    await tester.pumpWidget(
      MyApp(
        authRepository: authRepo,
        productRepository: productRepo,
        orderRepository: orderRepo,
        vendorRepository: vendorRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
