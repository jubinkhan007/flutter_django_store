import '../../domain/entities/product.dart';
import '../../domain/entities/variant.dart';
import '../../../../core/config/api_config.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    super.salePrice,
    super.vendorId,
    super.categoryId,
    super.stockQuantity,
    super.image,
    super.isAvailable,
    super.inStock,
    super.createdAt,
    super.options,
    super.variants,
    super.avgRating,
    super.reviewCount,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    var optionsList = (json['options'] as List?) ?? [];
    var variantsList = (json['variants'] as List?) ?? [];

    final rawStockQty = json['stock_quantity'];
    final parsedStockQty = rawStockQty == null
        ? 0
        : int.tryParse(rawStockQty.toString()) ?? 0;

    final bool derivedInStock = parsedStockQty > 0;
    final bool parsedInStock = json.containsKey('in_stock')
        ? (json['in_stock'] == true)
        : derivedInStock;

    final rawImage = json['image']?.toString();
    final resolvedImage = (rawImage == null || rawImage.trim().isEmpty)
        ? null
        : ApiConfig.resolveUrl(rawImage);

    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      salePrice: json['active_sale_price'] != null
          ? double.tryParse(json['active_sale_price'].toString())
          : null,
      vendorId: json['vendor'],
      categoryId: json['category'],
      stockQuantity: parsedStockQty,
      image: resolvedImage,
      isAvailable: json['is_available'] ?? true,
      inStock: parsedInStock,
      createdAt: json['created_at'],
      options: optionsList.map((o) => ProductOption.fromJson(o)).toList(),
      variants: variantsList.map((v) => ProductVariant.fromJson(v)).toList(),
      avgRating: double.tryParse(json['avg_rating']?.toString() ?? '0') ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      isSponsored: json['is_sponsored'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price.toString(),
      'stock_quantity': stockQuantity,
      'category': categoryId,
      'is_available': isAvailable,
    };
  }
}
