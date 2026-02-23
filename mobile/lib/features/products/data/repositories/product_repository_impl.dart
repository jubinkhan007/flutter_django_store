import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _apiClient;

  ProductRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    final queryParams = <String>[];

    if (query != null && query.isNotEmpty) queryParams.add('search=$query');
    if (categoryId != null) queryParams.add('category=$categoryId');
    if (minPrice != null) queryParams.add('min_price=$minPrice');
    if (maxPrice != null) queryParams.add('max_price=$maxPrice');
    if (sortBy != null && sortBy.isNotEmpty) queryParams.add('sort=$sortBy');

    String url = ApiConfig.productsUrl;
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await _apiClient.get(url, auth: false);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ProductModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load products');
    }
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
