import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/search_suggestion.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/product_facets_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _apiClient;

  ProductRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<SearchSuggestion>> getSearchSuggestions(String query) async {
    final uri = Uri.parse(
      ApiConfig.searchSuggestionsUrl,
    ).replace(queryParameters: {'q': query});
    final response = await _apiClient.get(uri.toString(), auth: false);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List results = data['results'] ?? [];
      return results.map((json) => SearchSuggestion.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load search suggestions');
    }
  }

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    List<String>? brands,
    double? minRating,
    int? minDiscount,
    bool? inStock,
  }) async {
    final params = <String, String>{};

    if (query != null && query.trim().isNotEmpty) params['search'] = query;
    if (categoryId != null) params['category'] = '$categoryId';
    if (minPrice != null) params['min_price'] = '$minPrice';
    if (maxPrice != null) params['max_price'] = '$maxPrice';
    if (sortBy != null && sortBy.isNotEmpty) params['sort'] = sortBy;
    if (brands != null && brands.isNotEmpty) params['brand'] = brands.join(',');
    if (minRating != null) params['min_rating'] = '$minRating';
    if (minDiscount != null) params['min_discount'] = '$minDiscount';
    if (inStock == true) params['in_stock'] = 'true';

    final uri = Uri.parse(ApiConfig.productsUrl).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await _apiClient.get(uri.toString(), auth: false);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ProductModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  @override
  Future<ProductFacets> getFacets({
    String? query,
    int? categoryId,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) params['search'] = query;
    if (categoryId != null) params['category'] = '$categoryId';

    final uri = Uri.parse(ApiConfig.productFacetsUrl).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await _apiClient.get(uri.toString(), auth: false);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ProductFacets.fromJson(data);
    } else {
      throw Exception('Failed to load product facets');
    }
  }

  @override
  Future<Map<String, List<String>>> getSearchHistory() async {
    final response = await _apiClient.get(ApiConfig.searchHistoryUrl, auth: true);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final recentList = (data['recent'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final trendingList = (data['trending'] as List?)?.map((e) => e.toString()).toList() ?? [];
      return {
        'recent': recentList,
        'trending': trendingList,
      };
    } else {
      return {'recent': [], 'trending': []};
    }
  }

  @override
  Future<void> saveSearchQuery(String query) async {
    if (query.trim().length < 2) return;
    try {
      await _apiClient.post(
        ApiConfig.searchHistoryUrl,
        body: {'query': query.trim()},
        auth: true,
      );
    } catch (_) {}
  }

  @override
  Future<void> clearSearchHistory() async {
    try {
      await _apiClient.delete(ApiConfig.searchHistoryUrl, auth: true);
    } catch (_) {}
  }

  @override
  Future<Product> getProductDetail(int id) async {
    final response = await _apiClient.get(
      '${ApiConfig.productsUrl}$id/',
      auth: false,
    );

    if (response.statusCode == 200) {
      return ProductModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load product');
    }
  }

  @override
  Future<List<Category>> getCategories() async {
    final response = await _apiClient.get(ApiConfig.categoriesUrl, auth: false);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }
}
