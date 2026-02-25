import 'dart:convert';
import 'dart:io';
import '../../../../core/network/api_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/home_feed_model.dart';

class HomeRepository {
  final ApiClient _apiClient;

  HomeRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<HomeFeed> getHomeFeed() async {
    // Get platform for targeting
    final platformStr = Platform.isIOS ? 'IOS' : 'ANDROID';

    final response = await _apiClient.get(
      '${ApiConfig.homeFeedUrl}?platform=$platformStr',
    );

    if (response.statusCode == 200) {
      return HomeFeed.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load home feed: ${response.statusCode}');
    }
  }
}
