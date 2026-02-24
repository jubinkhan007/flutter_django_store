import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/order_model.dart';

class OrderRepository {
  final ApiClient _apiClient;

  OrderRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Map<String, dynamic>> validateCoupon(
    String code,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _apiClient.post(
      ApiConfig.couponValidateUrl,
      body: {'code': code, 'items': items},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Invalid coupon');
    }
  }

  Future<OrderModel> placeOrder(
    List<Map<String, dynamic>> items,
    int addressId, {
    String paymentMethod = 'ONLINE',
    String? couponCode,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.placeOrderUrl,
      body: {
        'items': items,
        'address_id': addressId,
        'payment_method': paymentMethod,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'coupon_code': couponCode.trim(),
      },
    );

    if (response.statusCode == 201) {
      return OrderModel.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to place order');
    }
  }

  Future<List<OrderModel>> getOrderHistory() async {
    final response = await _apiClient.get(ApiConfig.ordersUrl);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<String> initiatePayment(int orderId) async {
    final response = await _apiClient.post(
      '${ApiConfig.ordersUrl}$orderId/pay/',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['GatewayPageURL'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to initiate payment');
    }
  }

  Future<void> cancelOrder(int orderId) async {
    final response = await _apiClient.post(
      '${ApiConfig.ordersUrl}$orderId/cancel/',
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to cancel order');
    }
  }
}
