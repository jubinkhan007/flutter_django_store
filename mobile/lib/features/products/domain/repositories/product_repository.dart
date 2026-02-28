import '../entities/product.dart';
import '../entities/category.dart';
import '../entities/search_suggestion.dart';

/// Abstract product repository interface.
abstract class ProductRepository {
  Future<List<SearchSuggestion>> getSearchSuggestions(String query);

  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  });
  Future<Product> getProductDetail(int id);
  Future<List<Category>> getCategories();
}
