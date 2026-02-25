import '../../domain/entities/product.dart';
import '../../domain/entities/variant.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    super.vendorId,
    super.categoryId,
    super.stockQuantity,
    super.image,
    super.isAvailable,
    super.inStock,
    super.createdAt,
    super.options,
    super.variants,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    var optionsList = (json['options'] as List?) ?? [];
    var variantsList = (json['variants'] as List?) ?? [];
    
    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      vendorId: json['vendor'],
      categoryId: json['category'],
      stockQuantity: json['stock_quantity'] ?? 0,
      image: json['image'],
      isAvailable: json['is_available'] ?? true,
      inStock: json['in_stock'] ?? true,
      createdAt: json['created_at'],
      options: optionsList.map((o) => ProductOption.fromJson(o)).toList(),
      variants: variantsList.map((v) => ProductVariant.fromJson(v)).toList(),
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
