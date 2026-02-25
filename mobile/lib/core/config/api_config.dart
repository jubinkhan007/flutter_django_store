import 'dart:io' show Platform;

class ApiConfig {
  // Android emulator uses 10.0.2.2 to reach the host machine's localhost
  // iOS simulator and web use localhost directly
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  // Auth endpoints
  static String get loginUrl => '$baseUrl/login/';
  static String get registerUrl => '$baseUrl/register/';
  static String get tokenRefreshUrl => '$baseUrl/auth/refresh/';
  static String get addressesUrl => '$baseUrl/auth/addresses/';

  // Coupons
  static String get couponsUrl => '$baseUrl/coupons/';
  static String get couponAvailableUrl => '$baseUrl/coupons/available/';
  static String get couponValidateUrl => '$baseUrl/coupons/validate/';

  // Returns / RMA
  static String get returnsUrl => '$baseUrl/returns/';

  // Product endpoints
  static String get productsUrl => '$baseUrl/products/';
  static String get categoriesUrl => '$baseUrl/products/categories/';
  static String get wishlistUrl => '$baseUrl/products/wishlist/';
  static String wishlistToggleUrl(int productId) =>
      '$wishlistUrl$productId/toggle/';

  // Review endpoints
  static String get reviewsUrl => '$baseUrl/reviews/';

  // Order endpoints
  static String get ordersUrl => '$baseUrl/orders/';
  static String get placeOrderUrl => '$baseUrl/orders/place/';

  // Vendor endpoints
  static String get vendorOnboardingUrl => '$baseUrl/vendors/onboarding/';
  static String get vendorDashboardUrl => '$baseUrl/vendors/me/';
  static String get vendorProductsUrl => '$baseUrl/vendors/products/';
  static String get vendorOrdersUrl => '$baseUrl/vendors/orders/';
  static String get vendorStatsUrl => '$baseUrl/vendors/stats/';
  static String get vendorCustomersUrl => '$baseUrl/vendors/customers/';
  static String get vendorCouponsUrl => '$baseUrl/vendors/coupons/';
  static String get vendorReturnsUrl => '$baseUrl/vendors/returns/';
}
