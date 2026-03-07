import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/cb_models.dart';

class CrossBorderRepository {
  final ApiClient _apiClient;

  CrossBorderRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<CrossBorderProduct>> fetchProducts() async {
    final response = await _apiClient.get(ApiConfig.cbProductsUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => CrossBorderProduct.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load cross-border products');
  }

  Future<CrossBorderProduct> fetchProductDetail(int id) async {
    final response = await _apiClient.get(ApiConfig.cbProductDetailUrl(id));
    if (response.statusCode == 200) {
      return CrossBorderProduct.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load product');
  }

  Future<List<CbShippingConfig>> fetchShippingConfigs() async {
    final response = await _apiClient.get(ApiConfig.cbShippingConfigUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => CbShippingConfig.fromJson(j as Map<String, dynamic>)).toList();
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
  }) async {
    final body = <String, dynamic>{
      if (productId != null) 'crossborder_product': productId,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      'marketplace': marketplace,
      'variant_notes': variantNotes,
      'quantity': quantity,
      'shipping_method': shippingMethod,
    };
    final response = await _apiClient.post(ApiConfig.cbRequestsUrl, body: body);
    if (response.statusCode == 201) {
      return CrossBorderOrderRequest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['error'] ?? err['detail'] ?? 'Failed to create request');
  }

  Future<List<CrossBorderOrderRequest>> fetchMyRequests() async {
    final response = await _apiClient.get(ApiConfig.cbRequestsListUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => CrossBorderOrderRequest.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load requests');
  }

  Future<CrossBorderOrderRequest> fetchRequestDetail(int id) async {
    final response = await _apiClient.get(ApiConfig.cbRequestDetailUrl(id));
    if (response.statusCode == 200) {
      return CrossBorderOrderRequest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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
      return CrossBorderOrderRequest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(err['error'] ?? err['detail'] ?? 'Checkout failed');
  }

  Future<void> markReceived(int requestId) async {
    final response = await _apiClient.post(ApiConfig.cbMarkReceivedUrl(requestId));
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Failed to mark as received');
    }
  }
}
