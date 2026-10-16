import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/delivery_estimate_model.dart';

class DeliveryEstimateRepository {
  final ApiClient _apiClient;

  DeliveryEstimateRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  Future<DeliveryEstimateModel> getEstimate({
    required int productId,
    String? city,
    String? area,
    int? variantId,
    int? quantity,
  }) async {
    final url = ApiConfig.deliveryEstimateUrl(
      productId: productId,
      city: city,
      area: area,
      variantId: variantId,
      quantity: quantity,
    );
    final response = await _apiClient.get(url, auth: true);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DeliveryEstimateModel.fromJson(data);
    }
    throw Exception('Failed to load delivery estimate (${response.statusCode})');
  }
}
