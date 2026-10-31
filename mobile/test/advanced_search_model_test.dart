import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/products/data/models/product_model.dart';
import 'package:mobile/features/products/data/models/product_facets_model.dart';

void main() {
  group('Advanced Search & Facets Models', () {
    test('ProductModel parses brand, discount_percent, and computes effectivePrice', () {
      final json = {
        'id': 101,
        'name': 'Wireless Noise-Cancelling Headphones',
        'description': 'Premium over-ear headphones',
        'price': '1000.00',
        'active_sale_price': null,
        'stock_quantity': 15,
        'in_stock': true,
        'brand': 'Sony',
        'discount_percent': 20,
        'avg_rating': 4.7,
        'review_count': 42,
        'is_sponsored': true,
        'campaign_id': 5,
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, equals(101));
      expect(product.name, equals('Wireless Noise-Cancelling Headphones'));
      expect(product.brand, equals('Sony'));
      expect(product.discountPercent, equals(20));
      expect(product.effectivePrice, closeTo(800.0, 0.01));
      expect(product.avgRating, equals(4.7));
      expect(product.reviewCount, equals(42));
      expect(product.isSponsored, isTrue);
      expect(product.campaignId, equals(5));
    });

    test('ProductFacets parses aggregated brands, categories, price range, and counts', () {
      final json = {
        'total_count': 120,
        'in_stock_count': 95,
        'price_range': {
          'min': 150.0,
          'max': 4500.0,
        },
        'brands': [
          {'name': 'Samsung', 'count': 25},
          {'name': 'Apple', 'count': 18},
          {'name': 'Sony', 'count': 12},
        ],
        'categories': [
          {'id': 1, 'name': 'Electronics', 'count': 50},
          {'id': 2, 'name': 'Audio', 'count': 30},
        ],
        'rating_counts': {
          '4_plus': 45,
          '3_plus': 80,
          '2_plus': 110,
        },
        'discount_counts': {
          '50_plus': 8,
          '25_plus': 32,
          '10_plus': 60,
        },
      };

      final facets = ProductFacets.fromJson(json);

      expect(facets.totalCount, equals(120));
      expect(facets.inStockCount, equals(95));
      expect(facets.priceRange.min, equals(150.0));
      expect(facets.priceRange.max, equals(4500.0));
      expect(facets.brands.length, equals(3));
      expect(facets.brands[0].name, equals('Samsung'));
      expect(facets.brands[0].count, equals(25));
      expect(facets.categories.length, equals(2));
      expect(facets.categories[0].name, equals('Electronics'));
      expect(facets.ratingCounts.fourPlus, equals(45));
      expect(facets.discountCounts.twentyFivePlus, equals(32));
    });
  });
}
