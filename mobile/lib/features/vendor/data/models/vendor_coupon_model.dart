class VendorCouponModel {
  final int id;
  final String code;
  final String discountType; // PERCENT, FIXED
  final double discountValue;
  final double? minOrderAmount;
  final bool isActive;
  final List<int> productIds;
  final List<int> categoryIds;
  final String createdAt;

  const VendorCouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount,
    required this.isActive,
    required this.productIds,
    required this.categoryIds,
    required this.createdAt,
  });

  factory VendorCouponModel.fromJson(Map<String, dynamic> json) {
    return VendorCouponModel(
      id: json['id'],
      code: json['code'] ?? '',
      discountType: json['discount_type'] ?? 'PERCENT',
      discountValue:
          double.tryParse(json['discount_value']?.toString() ?? '') ?? 0.0,
      minOrderAmount:
          json['min_order_amount'] == null
              ? null
              : (double.tryParse(json['min_order_amount'].toString()) ?? 0.0),
      isActive: json['is_active'] ?? true,
      productIds:
          (json['applicable_products'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((id) => id > 0)
              .toList() ??
          const [],
      categoryIds:
          (json['applicable_categories'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((id) => id > 0)
              .toList() ??
          const [],
      createdAt: json['created_at'] ?? '',
    );
  }
}

