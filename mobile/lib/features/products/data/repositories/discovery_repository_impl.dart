import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/product_recommendations.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../models/product_model.dart';

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final ApiClient _apiClient;

  DiscoveryRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<ProductRecommendations> getProductRecommendations(int productId) async {
    final response = await _apiClient.get(
      ApiConfig.discoveryProductRecommendationsUrl(productId),
      auth: false,
    );

    if (response.statusCode != 200) {
      debugPrint(
        'DiscoveryRepositoryImpl.getProductRecommendations($productId) failed: '
        '${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to load recommendations');
    }

    final data = jsonDecode(response.body);
    final similar = (data['similar_items'] as List?) ?? const [];
    final fbt = (data['frequently_bought_together'] as List?) ?? const [];

    return ProductRecommendations(
      similarItems: similar
          .whereType<Map>()
          .map((j) => ProductModel.fromJson(j.cast<String, dynamic>()))
          .toList(),
      frequentlyBoughtTogether: fbt
          .whereType<Map>()
          .map((j) => ProductModel.fromJson(j.cast<String, dynamic>()))
          .toList(),
    );
  }
}
