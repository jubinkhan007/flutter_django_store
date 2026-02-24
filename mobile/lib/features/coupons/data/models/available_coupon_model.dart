class AvailableCouponModel {
  final int id;
  final String code;
  final String scope; // GLOBAL, VENDOR
  final int? vendorId;
  final String? vendorName;
  final String discountType; // PERCENT, FIXED
  final double discountValue;
  final double? minOrderAmount;
  final double eligibleSubtotal;
  final double discount;
  final double totalAfterDiscount;

  const AvailableCouponModel({
    required this.id,
    required this.code,
    required this.scope,
    required this.vendorId,
    required this.vendorName,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.eligibleSubtotal,
    required this.discount,
    required this.totalAfterDiscount,
  });

  factory AvailableCouponModel.fromJson(Map<String, dynamic> json) {
    return AvailableCouponModel(
      id: json['id'],
      code: (json['code'] ?? '').toString(),
      scope: (json['scope'] ?? 'GLOBAL').toString(),
      vendorId: json['vendor_id'],
      vendorName: json['vendor_name'],
      discountType: (json['discount_type'] ?? 'PERCENT').toString(),
      discountValue:
          double.tryParse(json['discount_value']?.toString() ?? '') ?? 0.0,
      minOrderAmount:
          json['min_order_amount'] == null
              ? null
              : (double.tryParse(json['min_order_amount'].toString()) ?? 0.0),
      eligibleSubtotal:
          double.tryParse(json['eligible_subtotal']?.toString() ?? '') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '') ?? 0.0,
      totalAfterDiscount:
          double.tryParse(json['total_after_discount']?.toString() ?? '') ??
          0.0,
    );
  }
}

