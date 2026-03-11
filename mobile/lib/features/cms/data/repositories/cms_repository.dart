import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/cms_models.dart';

class CmsRepository {
  static const _bootstrapCacheKey = 'cms_bootstrap_cache_v1';

  final ApiClient _apiClient;

  CmsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<CmsBootstrap?> loadCachedBootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bootstrapCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CmsBootstrap.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheBootstrap(CmsBootstrap bootstrap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bootstrapCacheKey, jsonEncode(bootstrap.toJson()));
  }

  Future<CmsBootstrap> fetchBootstrap() async {
    final response = await _apiClient.get(ApiConfig.cmsBootstrapUrl, auth: false);
    if (response.statusCode == 200) {
      return CmsBootstrap.fromJson(
        (jsonDecode(response.body) as Map).cast<String, dynamic>(),
      );
    }
    throw Exception('Failed to load CMS bootstrap');
  }

  Future<CmsPageDetail> fetchPage({String? slug, String? pageType}) async {
    final uri = Uri.parse(ApiConfig.cmsPageResolveUrl).replace(
      queryParameters: {
        if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
        if (pageType != null && pageType.trim().isNotEmpty)
          'page_type': pageType.trim(),
      },
    );
    final response = await _apiClient.get(uri.toString(), auth: false);
    if (response.statusCode == 200) {
      return CmsPageDetail.fromJson(
        (jsonDecode(response.body) as Map).cast<String, dynamic>(),
      );
    }
    try {
      final err = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      throw Exception((err['detail'] ?? 'Failed to load page').toString());
    } catch (_) {
      throw Exception('Failed to load page');
    }
  }
}

