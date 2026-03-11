import 'dart:io' show Platform;
import 'package:mobile/core/config/app_config.dart';

class ApiConfig {
  static String get baseUrl {
    if (AppConfig.isProduction) {
      return AppConfig.backendApiUrl;
    }
    // Local Development
    if (Platform.isAndroid) {
      return AppConfig.localAndroidApiUrl;
    }
    return AppConfig.localIosApiUrl;
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
  static String get searchSuggestionsUrl => '${productsUrl}search/suggestions/';
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
  static String get vendorOnboardingProgressUrl =>
      '$baseUrl/vendors/onboarding/progress/';
  static String get vendorAnalyticsProductsUrl =>
      '$baseUrl/vendors/analytics/products/';
  static String get vendorAnalyticsSlaUrl => '$baseUrl/vendors/analytics/sla/';
  static String vendorPublicProfileUrl(int vendorId) =>
      '$baseUrl/vendors/public/$vendorId/';
  static String get vendorDashboardUrl => '$baseUrl/vendors/me/';
  static String get vendorProductsUrl => '$baseUrl/vendors/products/';
  static String get vendorOrdersUrl => '$baseUrl/vendors/orders/';
  static String get vendorStatsUrl => '$baseUrl/vendors/stats/';
  static String get vendorCustomersUrl => '$baseUrl/vendors/customers/';
  static String get vendorCouponsUrl => '$baseUrl/vendors/coupons/';
  static String get vendorReturnsUrl => '$baseUrl/vendors/returns/';
  static String get vendorLedgerUrl => '$baseUrl/vendors/ledger/';
  static String get vendorWalletSummaryUrl =>
      '$baseUrl/vendors/wallet/summary/';
  static String get vendorPayoutMethodsUrl =>
      '$baseUrl/vendors/payout-methods/';
  static String get vendorSettlementsUrl => '$baseUrl/vendors/settlements/';
  static String get vendorPayoutsUrl => '$baseUrl/vendors/payouts/';
  static String vendorSubOrderFulfillUrl(int subOrderId) =>
      '$baseUrl/vendors/sub-orders/$subOrderId/fulfill/';
  static String vendorSubOrderEventsUrl(int subOrderId) =>
      '$baseUrl/vendors/sub-orders/$subOrderId/events/';

  // Notifications
  static String get notificationsUrl => '$baseUrl/notifications/';
  static String get notificationUnreadCountUrl =>
      '${notificationsUrl}unread-count/';
  static String get notificationMarkAllReadUrl =>
      '${notificationsUrl}mark-all-read/';
  static String notificationMarkReadUrl(String id) =>
      '${notificationsUrl}$id/read/';
  static String get notificationPreferencesUrl =>
      '${notificationsUrl}preferences/';
  static String get notificationDeviceRegisterUrl =>
      '${notificationsUrl}devices/register/';

  // Support
  static String get supportTicketsUrl => '$baseUrl/support/tickets/';
  static String supportTicketDetailUrl(int ticketId) =>
      '$baseUrl/support/tickets/$ticketId/';
  static String supportTicketMessagesUrl(int ticketId) =>
      '$baseUrl/support/tickets/$ticketId/messages/';
  static String supportTicketAssignUrl(int ticketId) =>
      '$baseUrl/support/tickets/$ticketId/assign/';
  static String supportTicketStatusUrl(int ticketId) =>
      '$baseUrl/support/tickets/$ticketId/status/';
  static String supportTicketCloseUrl(int ticketId) =>
      '$baseUrl/support/tickets/$ticketId/close/';
  static String supportTicketReopenUrl(int ticketId) =>
      '$baseUrl/support/tickets/$ticketId/reopen/';

  // Returns
  static String returnEscalateUrl(int returnId) =>
      '${returnsUrl}$returnId/escalate/';

  // Logistics / Couriers
  static String get logisticsStoresUrl => '$baseUrl/logistics/stores/';
  static String get pathaoCitiesUrl => '$baseUrl/logistics/pathao/cities/';
  static String get pathaoStoresUrl => '$baseUrl/logistics/pathao/stores/';
  static String get pathaoZonesUrl => '$baseUrl/logistics/pathao/zones/';
  static String get pathaoAreasUrl => '$baseUrl/logistics/pathao/areas/';
  static String logisticsAreaSearchUrl(String courier) =>
      '$baseUrl/logistics/areas/$courier/search/';
  static String logisticsRetryProvisionUrl(int subOrderId) =>
      '$baseUrl/logistics/sub-orders/$subOrderId/retry/';

  // Analytics / Discovery
  static String get analyticsEventsUrl => '$baseUrl/analytics/events/';
  static String get discoveryHomeUrl => '$baseUrl/discovery/home/';
  static String discoveryProductRecommendationsUrl(int productId) =>
      '$baseUrl/discovery/product/$productId/recommendations/';
  static String collectionDetailUrl(String slug) =>
      '$baseUrl/collections/$slug/';

  // CMS
  static String get cmsBootstrapUrl => '$baseUrl/cms/bootstrap/';
  static String get cmsPageResolveUrl => '$baseUrl/cms/pages/resolve/';

  // Cross-Border
  static String get cbProductsUrl => '$baseUrl/crossborder/products/';
  static String cbProductDetailUrl(int id) =>
      '$baseUrl/crossborder/products/$id/';
  static String get cbShippingConfigUrl =>
      '$baseUrl/crossborder/shipping-config/';
  static String get cbRequestsUrl => '$baseUrl/crossborder/requests/';
  static String get cbRequestsListUrl => '$baseUrl/crossborder/requests/list/';
  static String cbRequestDetailUrl(int id) =>
      '$baseUrl/crossborder/requests/$id/';
  static String cbCheckoutUrl(int id) =>
      '$baseUrl/crossborder/requests/$id/checkout/';
  static String cbMarkReceivedUrl(int id) =>
      '$baseUrl/crossborder/requests/$id/mark-received/';
  static String get cbLinkPreviewUrl => '$baseUrl/crossborder/link-preview/';
}
