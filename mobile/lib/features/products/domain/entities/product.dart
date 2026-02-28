import 'variant.dart';

/// Domain entity for a Product.
class Product {
  final int id;
  final int? vendorId;
  final int? categoryId;
  final String name;
  final String description;
  final double price;

  /// Active flash sale price, null when no sale is running.
  final double? salePrice;
  final int stockQuantity;
  final String? image;
  final bool isAvailable;
  final bool inStock;
  final String? createdAt;
  final List<ProductOption> options;
  final List<ProductVariant> variants;
  final double avgRating;
  final int reviewCount;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.salePrice,
    this.vendorId,
    this.categoryId,
    this.stockQuantity = 0,
    this.image,
    this.isAvailable = true,
    this.inStock = true,
    this.createdAt,
    this.options = const [],
    this.variants = const [],
    this.avgRating = 0.0,
    this.reviewCount = 0,
  });

  /// The price the customer actually pays — sale price when active, base price otherwise.
  double get effectivePrice => salePrice ?? price;
}
