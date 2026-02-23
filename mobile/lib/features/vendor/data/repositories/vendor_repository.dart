import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../products/data/models/product_model.dart';
import '../../../orders/data/models/order_model.dart';

class VendorRepository {
  final ApiClient _apiClient;

  VendorRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Vendor onboarding — create a store
  Future<void> onboard(String storeName, String description) async {
    final response = await _apiClient.post(
      ApiConfig.vendorOnboardingUrl,
      body: {'store_name': storeName, 'description': description},
    );
    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Onboarding failed');
    }
  }

  /// Get vendor dashboard info
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _apiClient.get(ApiConfig.vendorDashboardUrl);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard');
    }
  }

  /// Get vendor business stats
  Future<Map<String, dynamic>> getStats() async {
    final response = await _apiClient.get(ApiConfig.vendorStatsUrl);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats');
    }
  }

  /// Get vendor's products
  Future<List<ProductModel>> getProducts() async {
    final response = await _apiClient.get(ApiConfig.vendorProductsUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ProductModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load vendor products');
    }
  }

  /// Add a new product
  Future<void> addProduct(Map<String, dynamic> productData) async {
    final response = await _apiClient.post(
      ApiConfig.vendorProductsUrl,
      body: productData,
    );
    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error.toString());
    }
  }

  /// Update a product
  Future<void> updateProduct(int productId, Map<String, dynamic> data) async {
    final response = await _apiClient.patch(
      '${ApiConfig.vendorProductsUrl}$productId/',
      body: data,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update product');
    }
  }

  /// Delete a product
  Future<void> deleteProduct(int productId) async {
    final response = await _apiClient.delete(
      '${ApiConfig.vendorProductsUrl}$productId/',
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product');
    }
  }

  /// Get vendor's orders
  Future<List<OrderModel>> getOrders() async {
    final response = await _apiClient.get(ApiConfig.vendorOrdersUrl);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load vendor orders');
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(int orderId, String status) async {
    final response = await _apiClient.patch(
      '${ApiConfig.vendorOrdersUrl}$orderId/',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update order status');
    }
  }
}
