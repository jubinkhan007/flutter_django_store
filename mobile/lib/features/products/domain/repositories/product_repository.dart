import '../entities/product.dart';
import '../entities/category.dart';

/// Abstract product repository interface.
abstract class ProductRepository {
  Future<List<Product>> getProducts({int? categoryId});
  Future<Product> getProductDetail(int id);
  Future<List<Category>> getCategories();
}
