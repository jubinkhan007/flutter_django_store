class CrossBorderProduct {
  final int id;
  final String title;
  final String description;
  final List<String> images;
  final String primaryImage;
  final String originMarketplace;
  final String sourceUrl;
  final double basePriceForeign;
  final String currency;
  final double estimatedWeightKg;
  final String policySummary;
  final int leadTimeDaysMin;
  final int leadTimeDaysMax;

  const CrossBorderProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.images,
    required this.primaryImage,
    required this.originMarketplace,
    required this.sourceUrl,
    required this.basePriceForeign,
    required this.currency,
    required this.estimatedWeightKg,
    required this.policySummary,
    required this.leadTimeDaysMin,
    required this.leadTimeDaysMax,
  });

  factory CrossBorderProduct.fromJson(Map<String, dynamic> json) {
    final imagesList = (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return CrossBorderProduct(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      images: imagesList,
      primaryImage: (json['primary_image'] ?? '').toString(),
      originMarketplace: json['origin_marketplace'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      basePriceForeign: double.tryParse(json['base_price_foreign']?.toString() ?? '0') ?? 0,
      currency: json['currency'] ?? 'USD',
      estimatedWeightKg: double.tryParse(json['estimated_weight_kg']?.toString() ?? '0') ?? 0,
      policySummary: json['policy_summary'] ?? '',
      leadTimeDaysMin: json['lead_time_days_min'] ?? 7,
      leadTimeDaysMax: json['lead_time_days_max'] ?? 21,
    );
  }
}

class CbCostBreakdown {
  final double itemPriceBdt;
  final double intlShippingBdt;
  final double serviceFeeBdt;
  final double customsEstBdt;
  final double totalBdt;
  final String currency;
  final double itemPriceForeign;
  final double fxRateBdt;

  const CbCostBreakdown({
    required this.itemPriceBdt,
    required this.intlShippingBdt,
    required this.serviceFeeBdt,
    required this.customsEstBdt,
    required this.totalBdt,
    required this.currency,
    required this.itemPriceForeign,
    required this.fxRateBdt,
  });

  factory CbCostBreakdown.fromJson(Map<String, dynamic> json) {
    return CbCostBreakdown(
      itemPriceBdt: (json['item_price_bdt'] ?? 0).toDouble(),
      intlShippingBdt: (json['intl_shipping_bdt'] ?? 0).toDouble(),
      serviceFeeBdt: (json['service_fee_bdt'] ?? 0).toDouble(),
      customsEstBdt: (json['customs_est_bdt'] ?? 0).toDouble(),
      totalBdt: (json['total_bdt'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      itemPriceForeign: (json['item_price_foreign'] ?? 0).toDouble(),
      fxRateBdt: (json['fx_rate_bdt'] ?? 110).toDouble(),
    );
  }
}

class CrossBorderOrderRequest {
  final int id;
  final String quoteId;
  final String requestType;
  final String title;
  final String status;
  final String sourceUrl;
  final String marketplace;
  final String variantNotes;
  final int quantity;
  final String shippingMethod;
  final CbCostBreakdown? costBreakdown;
  final bool isQuoteValid;
  final String? quoteExpiresAt;
  final int expectedDeliveryDaysMin;
  final int expectedDeliveryDaysMax;
  final String carrierName;
  final String trackingNumber;
  final String trackingUrl;
  final String supplierOrderId;
  final String createdAt;
  final String? shippedIntlAt;
  final String? deliveredAt;

  const CrossBorderOrderRequest({
    required this.id,
    required this.quoteId,
    required this.requestType,
    required this.title,
    required this.status,
    required this.sourceUrl,
    required this.marketplace,
    required this.variantNotes,
    required this.quantity,
    required this.shippingMethod,
    this.costBreakdown,
    required this.isQuoteValid,
    this.quoteExpiresAt,
    required this.expectedDeliveryDaysMin,
    required this.expectedDeliveryDaysMax,
    required this.carrierName,
    required this.trackingNumber,
    required this.trackingUrl,
    required this.supplierOrderId,
    required this.createdAt,
    this.shippedIntlAt,
    this.deliveredAt,
  });

  factory CrossBorderOrderRequest.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['estimated_cost_breakdown'];
    return CrossBorderOrderRequest(
      id: json['id'] ?? 0,
      quoteId: json['quote_id'] ?? '',
      requestType: json['request_type'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      marketplace: json['marketplace'] ?? '',
      variantNotes: json['variant_notes'] ?? '',
      quantity: json['quantity'] ?? 1,
      shippingMethod: json['shipping_method'] ?? 'AIR',
      costBreakdown: (breakdownRaw is Map && breakdownRaw.isNotEmpty)
          ? CbCostBreakdown.fromJson(breakdownRaw.cast<String, dynamic>())
          : null,
      isQuoteValid: json['is_quote_valid'] == true,
      quoteExpiresAt: json['quote_expires_at']?.toString(),
      expectedDeliveryDaysMin: json['expected_delivery_days_min'] ?? 7,
      expectedDeliveryDaysMax: json['expected_delivery_days_max'] ?? 21,
      carrierName: json['carrier_name'] ?? '',
      trackingNumber: json['tracking_number'] ?? '',
      trackingUrl: json['tracking_url'] ?? '',
      supplierOrderId: json['supplier_order_id'] ?? '',
      createdAt: json['created_at'] ?? '',
      shippedIntlAt: json['shipped_intl_at']?.toString(),
      deliveredAt: json['delivered_at']?.toString(),
    );
  }

  bool get isActive => ![
    'DELIVERED', 'CANCELLED', 'REFUND_IN_PROGRESS',
  ].contains(status);

  bool get hasTracking => trackingUrl.isNotEmpty || trackingNumber.isNotEmpty;
}

class CbShippingConfig {
  final String shippingMethod;
  final double ratePerKg;
  final String serviceFeeType;
  final double serviceFeeValue;
  final double customsRatePercentage;
  final double fxRateBdt;

  const CbShippingConfig({
    required this.shippingMethod,
    required this.ratePerKg,
    required this.serviceFeeType,
    required this.serviceFeeValue,
    required this.customsRatePercentage,
    required this.fxRateBdt,
  });

  factory CbShippingConfig.fromJson(Map<String, dynamic> json) {
    return CbShippingConfig(
      shippingMethod: json['shipping_method'] ?? '',
      ratePerKg: double.tryParse(json['rate_per_kg']?.toString() ?? '0') ?? 0,
      serviceFeeType: json['service_fee_type'] ?? 'PERCENTAGE',
      serviceFeeValue: double.tryParse(json['service_fee_value']?.toString() ?? '0') ?? 0,
      customsRatePercentage: double.tryParse(json['customs_rate_percentage']?.toString() ?? '0') ?? 0,
      fxRateBdt: double.tryParse(json['fx_rate_bdt']?.toString() ?? '110') ?? 110,
    );
  }
}
