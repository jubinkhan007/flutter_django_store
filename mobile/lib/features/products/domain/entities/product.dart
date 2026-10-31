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
  final String brand;
  final int discountPercent;
  final double avgRating;
  final int reviewCount;
  final bool isSponsored;
  final int? campaignId;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.brand = '',
    this.discountPercent = 0,
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
    this.isSponsored = false,
    this.campaignId,
  });

  /// The price the customer actually pays — sale price when active, discounted price if discountPercent > 0, base price otherwise.
  double get effectivePrice {
    if (salePrice != null) return salePrice!;
    if (discountPercent > 0) {
      return price * (1.0 - (discountPercent / 100.0));
    }
    return price;
  }
}
