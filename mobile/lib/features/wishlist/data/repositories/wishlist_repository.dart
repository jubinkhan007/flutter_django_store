import 'dart:convert';
import 'package:mobile/core/config/api_config.dart';
import 'package:mobile/core/network/api_client.dart';
import '../models/wishlist_item_model.dart';

class WishlistRepository {
  final ApiClient _apiClient;

  WishlistRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<WishlistItemModel>> getWishlist() async {
    final response = await _apiClient.get(ApiConfig.wishlistUrl);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => WishlistItemModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load wishlist');
    }
  }

  Future<bool> toggleWishlist(int productId) async {
    final response = await _apiClient.post(
      ApiConfig.wishlistToggleUrl(productId),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['status'] == 'added';
    } else {
      throw Exception('Failed to toggle wishlist');
    }
  }
}
