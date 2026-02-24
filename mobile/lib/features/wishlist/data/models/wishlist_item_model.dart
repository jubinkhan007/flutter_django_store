class WishlistItemModel {
  final int id;
  final int productId;
  final String productName;
  final double productPrice;
  final String? productImage;
  final bool productInStock;
  final String addedAt;

  WishlistItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productPrice,
    this.productImage,
    required this.productInStock,
    required this.addedAt,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    final productDetail = json['product_detail'] ?? {};
    return WishlistItemModel(
      id: json['id'],
      productId: json['product'],
      productName: productDetail['name'] ?? '',
      productPrice:
          double.tryParse(productDetail['price']?.toString() ?? '0') ?? 0,
      productImage: productDetail['image'],
      productInStock: productDetail['in_stock'] ?? false,
      addedAt: json['added_at'] ?? '',
    );
  }
}
