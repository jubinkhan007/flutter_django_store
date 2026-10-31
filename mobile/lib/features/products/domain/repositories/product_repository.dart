import '../entities/product.dart';
import '../entities/category.dart';
import '../entities/search_suggestion.dart';
import '../../data/models/product_facets_model.dart';

/// Abstract product repository interface.
abstract class ProductRepository {
  Future<List<SearchSuggestion>> getSearchSuggestions(String query);

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
  });

  Future<ProductFacets> getFacets({
    String? query,
    int? categoryId,
  });

  Future<Map<String, List<String>>> getSearchHistory();
  Future<void> saveSearchQuery(String query);
  Future<void> clearSearchHistory();

  Future<Product> getProductDetail(int id);
  Future<List<Category>> getCategories();
}
