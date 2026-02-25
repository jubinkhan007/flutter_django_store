/// Server-validated checkout pricing breakdown.
/// Used as a single source of truth for pricing across
/// checkout review step, order summary card, and confirmation screen.
class CheckoutQuote {
  final double subtotal;
  final double discount;
  final double shipping;
  final double tax;
  final double total;
  final String? couponLabel;
  final List<QuoteItem> items;
  final List<StockWarning> stockWarnings;

  const CheckoutQuote({
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.tax,
    required this.total,
    this.couponLabel,
    required this.items,
    required this.stockWarnings,
  });

  bool get hasStockWarnings => stockWarnings.isNotEmpty;

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    return CheckoutQuote(
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '') ?? 0.0,
      shipping: double.tryParse(json['shipping']?.toString() ?? '') ?? 0.0,
      tax: double.tryParse(json['tax']?.toString() ?? '') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '') ?? 0.0,
      couponLabel: json['coupon_label'],
      items:
          (json['items'] as List?)
              ?.map((e) => QuoteItem.fromJson(e))
              .toList() ??
          [],
      stockWarnings:
          (json['stock_warnings'] as List?)
              ?.map((e) => StockWarning.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class QuoteItem {
  final int productId;
  final String productName;
  final int? variantId;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String? imageUrl;

  const QuoteItem({
    required this.productId,
    required this.productName,
    this.variantId,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.imageUrl,
  });

  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      variantId: json['variant_id'],
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '') ?? 0.0,
      quantity: json['quantity'] ?? 1,
      lineTotal: double.tryParse(json['line_total']?.toString() ?? '') ?? 0.0,
      imageUrl: json['image_url'],
    );
  }
}

class StockWarning {
  final int productId;
  final String productName;
  final int? variantId;
  final int requested;
  final int available;

  const StockWarning({
    required this.productId,
    required this.productName,
    this.variantId,
    required this.requested,
    required this.available,
  });

  factory StockWarning.fromJson(Map<String, dynamic> json) {
    return StockWarning(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      variantId: json['variant_id'],
      requested: json['requested'] ?? 0,
      available: json['available'] ?? 0,
    );
  }
}
