class CouponModel {
  final int id;
  final String code;
  final String scope; // GLOBAL, VENDOR
  final int? vendorId;
  final String? vendorName;
  final String discountType; // PERCENT, FIXED
  final double discountValue;
  final double? minOrderAmount;
  final List<int> applicableProductIds;
  final List<int> applicableCategoryIds;

  const CouponModel({
    required this.id,
    required this.code,
    required this.scope,
    required this.vendorId,
    required this.vendorName,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.applicableProductIds,
    required this.applicableCategoryIds,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'],
      code: (json['code'] ?? '').toString(),
      scope: (json['scope'] ?? 'GLOBAL').toString(),
      vendorId: json['vendor'],
      vendorName: json['vendor_name'],
      discountType: (json['discount_type'] ?? 'PERCENT').toString(),
      discountValue:
          double.tryParse(json['discount_value']?.toString() ?? '') ?? 0.0,
      minOrderAmount:
          json['min_order_amount'] == null
              ? null
              : (double.tryParse(json['min_order_amount'].toString()) ?? 0.0),
      applicableProductIds:
          (json['applicable_product_ids'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          const [],
      applicableCategoryIds:
          (json['applicable_category_ids'] as List?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          const [],
    );
  }
}

