import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/cb_models.dart';

class CrossBorderRepository {
  final ApiClient _apiClient;

  CrossBorderRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  String _extractErrorMessage(dynamic json) {
    if (json is Map<String, dynamic>) {
      final direct = (json['error'] ?? json['detail'])?.toString();
      if (direct != null && direct.isNotEmpty) return direct;
      if (json.isNotEmpty) {
        final entry = json.entries.first;
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List && value.isNotEmpty) return '$key: ${value.first}';
        if (value != null) return '$key: $value';
      }
    }
    if (json is List && json.isNotEmpty) return json.first.toString();
    return 'Request failed';
  }

  Future<List<CrossBorderProduct>> fetchProducts() async {
    final response = await _apiClient.get(ApiConfig.cbProductsUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((j) => CrossBorderProduct.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load cross-border products');
  }

  Future<CrossBorderProduct> fetchProductDetail(int id) async {
    final response = await _apiClient.get(ApiConfig.cbProductDetailUrl(id));
    if (response.statusCode == 200) {
      return CrossBorderProduct.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to load product');
  }

  Future<List<CbShippingConfig>> fetchShippingConfigs() async {
    final response = await _apiClient.get(ApiConfig.cbShippingConfigUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((j) => CbShippingConfig.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load shipping config');
  }

  Future<CrossBorderOrderRequest> createRequest({
    int? productId,
    String? sourceUrl,
    required String marketplace,
    required String variantNotes,
    required int quantity,
    required String shippingMethod,
    double? itemPriceForeign,
    String? currency,
    double? estimatedWeightKg,
  }) async {
    final body = <String, dynamic>{
      'request_type': productId != null ? 'CATALOG_ITEM' : 'LINK_PURCHASE',
      if (productId != null) 'crossborder_product_id': productId,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      'marketplace': marketplace,
      'variant_notes': variantNotes,
      'quantity': quantity,
      'shipping_method': shippingMethod,
      if (itemPriceForeign != null) 'item_price_foreign': itemPriceForeign,
      if (currency != null && currency.isNotEmpty) 'currency': currency,
      if (estimatedWeightKg != null) 'estimated_weight_kg': estimatedWeightKg,
    };
    final response = await _apiClient.post(ApiConfig.cbRequestsUrl, body: body);
    if (response.statusCode == 201) {
      return CrossBorderOrderRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    try {
      final errJson = jsonDecode(response.body);
      throw Exception(_extractErrorMessage(errJson));
    } catch (_) {
      throw Exception('Failed to create request');
    }
  }

  Future<List<CrossBorderOrderRequest>> fetchMyRequests() async {
    final response = await _apiClient.get(ApiConfig.cbRequestsListUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map(
            (j) => CrossBorderOrderRequest.fromJson(j as Map<String, dynamic>),
          )
          .toList();
    }
    throw Exception('Failed to load requests');
  }

  Future<CrossBorderOrderRequest> fetchRequestDetail(int id) async {
    final response = await _apiClient.get(ApiConfig.cbRequestDetailUrl(id));
    if (response.statusCode == 200) {
      return CrossBorderOrderRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to load request');
  }

  Future<CrossBorderOrderRequest> checkout({
    required int requestId,
    required int addressId,
    required bool customsPolicyAcknowledged,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.cbCheckoutUrl(requestId),
      body: {
        'address_id': addressId,
        'customs_policy_acknowledged': customsPolicyAcknowledged,
      },
    );
    if (response.statusCode == 200) {
      return CrossBorderOrderRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['error'] ?? err['detail'] ?? 'Checkout failed');
  }

  Future<CbLinkPreview> fetchLinkPreview(String url) async {
    final uri = Uri.parse(ApiConfig.cbLinkPreviewUrl)
        .replace(queryParameters: {'url': url});
    final response = await _apiClient.get(uri.toString());
    if (response.statusCode == 200) {
      return CbLinkPreview.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['error'] ?? 'Could not fetch product details');
  }

  Future<void> markReceived(int requestId) async {
    final response = await _apiClient.post(
      ApiConfig.cbMarkReceivedUrl(requestId),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Failed to mark as received');
    }
  }
}
