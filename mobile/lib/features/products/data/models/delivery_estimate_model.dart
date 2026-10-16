class DeliveryOptionModel {
  final String code;
  final String title;
  final String courierPartner;
  final double fee;
  final String feeDisplay;
  final bool isFree;
  final int minDays;
  final int maxDays;
  final String estimatedDeliveryStart;
  final String estimatedDeliveryEnd;
  final String estimatedDeliveryDisplay;
  final String badge;

  const DeliveryOptionModel({
    required this.code,
    required this.title,
    required this.courierPartner,
    required this.fee,
    required this.feeDisplay,
    required this.isFree,
    required this.minDays,
    required this.maxDays,
    required this.estimatedDeliveryStart,
    required this.estimatedDeliveryEnd,
    required this.estimatedDeliveryDisplay,
    required this.badge,
  });

  factory DeliveryOptionModel.fromJson(Map<String, dynamic> json) {
    return DeliveryOptionModel(
      code: json['code'] as String? ?? 'STANDARD',
      title: json['title'] as String? ?? 'Standard Delivery',
      courierPartner: json['courier_partner'] as String? ?? '',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      feeDisplay: json['fee_display'] as String? ?? '৳0',
      isFree: json['is_free'] as bool? ?? false,
      minDays: json['min_days'] as int? ?? 2,
      maxDays: json['max_days'] as int? ?? 3,
      estimatedDeliveryStart: json['estimated_delivery_start'] as String? ?? '',
      estimatedDeliveryEnd: json['estimated_delivery_end'] as String? ?? '',
      estimatedDeliveryDisplay: json['estimated_delivery_display'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
    );
  }
}

class DeliveryEstimateModel {
  final String destinationCity;
  final String destinationArea;
  final bool isInsideCity;
  final String vendorName;
  final String vendorCity;
  final List<DeliveryOptionModel> options;
  final bool codAvailable;
  final String codFeeDisplay;
  final int returnWindowDays;
  final bool allowReturn;
  final String returnPolicyNote;
  final double freeShippingThreshold;
  final bool qualifiesForFreeShipping;

  const DeliveryEstimateModel({
    required this.destinationCity,
    required this.destinationArea,
    required this.isInsideCity,
    required this.vendorName,
    required this.vendorCity,
    required this.options,
    required this.codAvailable,
    required this.codFeeDisplay,
    required this.returnWindowDays,
    required this.allowReturn,
    required this.returnPolicyNote,
    required this.freeShippingThreshold,
    required this.qualifiesForFreeShipping,
  });

  factory DeliveryEstimateModel.fromJson(Map<String, dynamic> json) {
    final dest = (json['destination'] as Map<String, dynamic>?) ?? {};
    final origin = (json['origin'] as Map<String, dynamic>?) ?? {};
    final rawOptions = (json['options'] as List?) ?? [];
    final cod = (json['cash_on_delivery'] as Map<String, dynamic>?) ?? {};
    final ret = (json['return_policy'] as Map<String, dynamic>?) ?? {};

    return DeliveryEstimateModel(
      destinationCity: dest['city'] as String? ?? 'Dhaka',
      destinationArea: dest['area'] as String? ?? '',
      isInsideCity: dest['is_inside_city'] as bool? ?? true,
      vendorName: origin['vendor_name'] as String? ?? 'Store',
      vendorCity: origin['vendor_city'] as String? ?? 'Dhaka',
      options: rawOptions
          .map((item) => DeliveryOptionModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      codAvailable: cod['is_available'] as bool? ?? true,
      codFeeDisplay: cod['fee_display'] as String? ?? 'Free',
      returnWindowDays: ret['return_window_days'] as int? ?? 7,
      allowReturn: ret['allow_return'] as bool? ?? true,
      returnPolicyNote: ret['policy_note'] as String? ?? '7 Days Easy Return',
      freeShippingThreshold: (json['free_shipping_threshold'] as num?)?.toDouble() ?? 2000.0,
      qualifiesForFreeShipping: json['qualifies_for_free_shipping'] as bool? ?? false,
    );
  }

  DeliveryOptionModel? get standardOption {
    try {
      return options.firstWhere((o) => o.code == 'STANDARD');
    } catch (_) {
      return options.isNotEmpty ? options.first : null;
    }
  }

  DeliveryOptionModel? get expressOption {
    try {
      return options.firstWhere((o) => o.code == 'EXPRESS');
    } catch (_) {
      return null;
    }
  }

  String get formattedDestination {
    if (destinationArea.isNotEmpty) {
      return '$destinationArea, $destinationCity';
    }
    return destinationCity;
  }
}
