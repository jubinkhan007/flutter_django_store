import 'product.dart';

class ProductRecommendations {
  final List<Product> similarItems;
  final List<Product> frequentlyBoughtTogether;

  const ProductRecommendations({
    this.similarItems = const [],
    this.frequentlyBoughtTogether = const [],
  });
}

