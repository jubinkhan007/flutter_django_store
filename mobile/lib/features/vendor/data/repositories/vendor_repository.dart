import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../products/data/models/product_model.dart';
import '../../../orders/data/models/order_model.dart';
import '../../data/models/vendor_customer_model.dart';
import '../../data/models/vendor_coupon_model.dart';

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
  Future<void> addProduct({
    required Map<String, String> fields,
    http.MultipartFile? imageFile,
  }) async {
    final response = await _apiClient.postMultipart(
      ApiConfig.vendorProductsUrl,
      fields: fields,
      file: imageFile,
    );

    if (response.statusCode != 201) {
      final responseBody = await response.stream.bytesToString();
      try {
        final error = jsonDecode(responseBody);
        throw Exception(error.toString());
      } catch (_) {
        throw Exception('Failed to add product: ${response.statusCode}');
      }
    }
  }

  /// Update a product
  Future<void> updateProduct({
    required int productId,
    required Map<String, String> fields,
    http.MultipartFile? imageFile,
  }) async {
    final response = await _apiClient.putMultipart(
      '${ApiConfig.vendorProductsUrl}$productId/',
      fields: fields,
      file: imageFile,
    );

    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      try {
        final error = jsonDecode(responseBody);
        throw Exception(error.toString());
      } catch (_) {
        throw Exception('Failed to update product: ${response.statusCode}');
      }
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

  /// Cancel and refund order
  Future<void> cancelOrder(int orderId) async {
    final response = await _apiClient.post(
      '${ApiConfig.vendorOrdersUrl}$orderId/cancel/',
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to cancel order');
    }
  }

  /// Load customers for the vendor
  Future<List<VendorCustomerModel>> loadCustomers() async {
    final response = await _apiClient.get(ApiConfig.vendorCustomersUrl);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => VendorCustomerModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load customers');
    }
  }

  Future<List<VendorCouponModel>> getCoupons() async {
    final response = await _apiClient.get(ApiConfig.vendorCouponsUrl);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => VendorCouponModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load coupons');
    }
  }

  Future<VendorCouponModel> createCoupon({
    required String code,
    required String discountType,
    required double discountValue,
    double? minOrderAmount,
    List<int> productIds = const [],
    List<int> categoryIds = const [],
  }) async {
    final body = <String, dynamic>{
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      if (minOrderAmount != null) 'min_order_amount': minOrderAmount,
      if (productIds.isNotEmpty) 'product_ids': productIds,
      if (categoryIds.isNotEmpty) 'category_ids': categoryIds,
    };

    final response = await _apiClient.post(ApiConfig.vendorCouponsUrl, body: body);

    if (response.statusCode == 201) {
      return VendorCouponModel.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error.toString());
    }
  }

  Future<void> uploadBulkJob(String jobType, String filePath) async {
    final file = await http.MultipartFile.fromPath('file', filePath);
    final response = await _apiClient.postMultipart(
      'vendors/bulk-jobs/',
      fields: {'job_type': jobType},
      file: file,
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to upload bulk job: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getBulkJobs() async {
    final response = await _apiClient.get('vendors/bulk-jobs/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load bulk jobs');
    }
  }
}
