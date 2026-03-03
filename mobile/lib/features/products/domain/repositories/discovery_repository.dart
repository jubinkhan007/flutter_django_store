import '../entities/product_recommendations.dart';

abstract class DiscoveryRepository {
  Future<ProductRecommendations> getProductRecommendations(int productId);
}

