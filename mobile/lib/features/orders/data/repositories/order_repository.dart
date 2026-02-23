import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/order_model.dart';

class OrderRepository {
  final ApiClient _apiClient;

  OrderRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<OrderModel> placeOrder(List<Map<String, dynamic>> items) async {
    final response = await _apiClient.post(
      ApiConfig.placeOrderUrl,
      body: {'items': items},
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
}
