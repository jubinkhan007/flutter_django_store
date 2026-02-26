import '../../../../core/config/api_config.dart';

class ReturnRequestModel {
  final int id;
  final String rmaNumber;
  final int orderId;
  final int vendorId;
  final String requestType; // RETURN, REPLACE
  final String status;
  final String reason;
  final String reasonDetails;
  final String fulfillment; // PICKUP, DROPOFF
  final String refundMethodPreference; // ORIGINAL, WALLET
  final DateTime? pickupWindowStart;
  final DateTime? pickupWindowEnd;
  final String dropoffInstructions;
  final String vendorNote;
  final String customerNote;
  final DateTime? vendorResponseDueAt;
  final DateTime? escalatedAt;
  final List<ReturnItemModel> items;
  final List<ReturnImageModel> images;
  final List<RefundModel> refunds;
  final String createdAt;

  const ReturnRequestModel({
    required this.id,
    required this.rmaNumber,
    required this.orderId,
    required this.vendorId,
    required this.requestType,
    required this.status,
    required this.reason,
    required this.reasonDetails,
    required this.fulfillment,
    required this.refundMethodPreference,
    required this.pickupWindowStart,
    required this.pickupWindowEnd,
    required this.dropoffInstructions,
    required this.vendorNote,
    required this.customerNote,
    required this.vendorResponseDueAt,
    required this.escalatedAt,
    required this.items,
    required this.images,
    required this.refunds,
    required this.createdAt,
  });

  factory ReturnRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return ReturnRequestModel(
      id: json['id'],
      rmaNumber: json['rma_number'] ?? '',
      orderId: json['order'],
      vendorId: json['vendor'],
      requestType: json['request_type'] ?? 'RETURN',
      status: json['status'] ?? 'SUBMITTED',
      reason: json['reason'] ?? 'OTHER',
      reasonDetails: json['reason_details'] ?? '',
      fulfillment: json['fulfillment'] ?? 'PICKUP',
      refundMethodPreference: json['refund_method_preference'] ?? 'ORIGINAL',
      pickupWindowStart: parseDate(json['pickup_window_start']),
      pickupWindowEnd: parseDate(json['pickup_window_end']),
      dropoffInstructions: json['dropoff_instructions'] ?? '',
      vendorNote: json['vendor_note'] ?? '',
      customerNote: json['customer_note'] ?? '',
      vendorResponseDueAt: parseDate(json['vendor_response_due_at']),
      escalatedAt: parseDate(json['escalated_at']),
      items:
          (json['items'] as List?)
              ?.map((e) => ReturnItemModel.fromJson(e))
              .toList() ??
          const [],
      images:
          (json['images'] as List?)
              ?.map((e) => ReturnImageModel.fromJson(e))
              .toList() ??
          const [],
      refunds:
          (json['refunds'] as List?)
              ?.map((e) => RefundModel.fromJson(e))
              .toList() ??
          const [],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ReturnItemModel {
  final int id;
  final int orderItemId;
  final int quantity;
  final String condition;
  final String productName;

  const ReturnItemModel({
    required this.id,
    required this.orderItemId,
    required this.quantity,
    required this.condition,
    required this.productName,
  });

  factory ReturnItemModel.fromJson(Map<String, dynamic> json) {
    final productDetail = json['product_detail'] as Map<String, dynamic>?;
    return ReturnItemModel(
      id: json['id'],
      orderItemId: json['order_item'],
      quantity: json['quantity'] ?? 1,
      condition: json['condition'] ?? 'UNOPENED',
      productName: productDetail?['name'] ?? 'Product',
    );
  }
}

class ReturnImageModel {
  final int id;
  final String imageUrl;
  final String uploadedAt;

  const ReturnImageModel({
    required this.id,
    required this.imageUrl,
    required this.uploadedAt,
  });

  factory ReturnImageModel.fromJson(Map<String, dynamic> json) {
    return ReturnImageModel(
      id: json['id'],
      imageUrl: ApiConfig.resolveUrl(json['image'] ?? ''),
      uploadedAt: json['uploaded_at'] ?? '',
    );
  }
}

class RefundModel {
  final int id;
  final double amount;
  final String method;
  final String status;
  final String? processedAt;

  const RefundModel({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    this.processedAt,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'],
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      method: json['method'] ?? 'ORIGINAL',
      status: json['status'] ?? 'PENDING',
      processedAt: json['processed_at'],
    );
  }
}
