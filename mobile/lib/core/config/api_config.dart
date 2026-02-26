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

  /// Base origin (scheme + host + optional port), e.g. http://10.0.2.2:8000
  static String get origin {
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Resolve backend-provided relative URLs (e.g. `/media/...`) into absolute URLs.
  static String resolveUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '$origin$trimmed';
    return '$origin/$trimmed';
  }

  // Auth endpoints
  static String get loginUrl => '$baseUrl/login/';
  static String get registerUrl => '$baseUrl/register/';
  static String get tokenRefreshUrl => '$baseUrl/auth/refresh/';
  static String get addressesUrl => '$baseUrl/auth/addresses/';

  // Home / Promotions
  static String get homeFeedUrl => '$baseUrl/promotions/home-feed/';

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
  static String get checkoutQuoteUrl => '$baseUrl/orders/quote/';

  // Vendor endpoints
  static String get vendorOnboardingUrl => '$baseUrl/vendors/onboarding/';
  static String get vendorDashboardUrl => '$baseUrl/vendors/me/';
  static String get vendorProductsUrl => '$baseUrl/vendors/products/';
  static String get vendorOrdersUrl => '$baseUrl/vendors/orders/';
  static String get vendorStatsUrl => '$baseUrl/vendors/stats/';
  static String get vendorCustomersUrl => '$baseUrl/vendors/customers/';
  static String get vendorCouponsUrl => '$baseUrl/vendors/coupons/';
  static String get vendorReturnsUrl => '$baseUrl/vendors/returns/';
  static String vendorSubOrderFulfillUrl(int subOrderId) =>
      '$baseUrl/vendors/sub-orders/$subOrderId/fulfill/';
  static String vendorSubOrderEventsUrl(int subOrderId) =>
      '$baseUrl/vendors/sub-orders/$subOrderId/events/';
}
