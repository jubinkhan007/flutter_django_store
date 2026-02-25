class ProductOptionValue {
  final int id;
  final String value;
  final String slug;

  const ProductOptionValue({
    required this.id,
    required this.value,
    required this.slug,
  });

  factory ProductOptionValue.fromJson(Map<String, dynamic> json) {
    return ProductOptionValue(
      id: json['id'],
      value: json['value'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class ProductOption {
  final int id;
  final String name;
  final String slug;
  final List<ProductOptionValue> values;

  const ProductOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.values,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    var valuesList = (json['values'] as List?) ?? [];
    return ProductOption(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      values: valuesList.map((v) => ProductOptionValue.fromJson(v)).toList(),
    );
  }
}

class ProductVariant {
  final int id;
  final String sku;
  final String? barcode;
  final double? priceOverride;
  final double effectivePrice;
  final int stockOnHand;
  final int reservedStock;
  final int lowStockThreshold;
  final int stockAvailable;
  final bool isActive;
  final List<int> optionValueIds;

  const ProductVariant({
    required this.id,
    required this.sku,
    this.barcode,
    this.priceOverride,
    required this.effectivePrice,
    required this.stockOnHand,
    required this.reservedStock,
    required this.lowStockThreshold,
    required this.stockAvailable,
    required this.isActive,
    required this.optionValueIds,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      sku: json['sku'] ?? '',
      barcode: json['barcode'],
      priceOverride: json['price_override'] != null ? double.tryParse(json['price_override'].toString()) : null,
      effectivePrice: double.tryParse(json['effective_price'].toString()) ?? 0.0,
      stockOnHand: json['stock_on_hand'] ?? 0,
      reservedStock: json['reserved_stock'] ?? 0,
      lowStockThreshold: json['low_stock_threshold'] ?? 0,
      stockAvailable: json['stock_available'] ?? 0,
      isActive: json['is_active'] ?? true,
      optionValueIds: List<int>.from(json['option_value_ids'] ?? []),
    );
  }
}
