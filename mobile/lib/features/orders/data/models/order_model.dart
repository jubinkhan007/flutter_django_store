import '../../../addresses/data/models/address_model.dart';

class ShipmentEventModel {
  final int id;
  final String status;
  final String location;
  final String timestamp;
  final String description;
  final int sequence;
  final String source;

  const ShipmentEventModel({
    required this.id,
    required this.status,
    required this.location,
    required this.timestamp,
    required this.description,
    required this.sequence,
    required this.source,
  });

  factory ShipmentEventModel.fromJson(Map<String, dynamic> json) {
    return ShipmentEventModel(
      id: json['id'] ?? 0,
      status: json['status'] ?? '',
      location: json['location'] ?? '',
      timestamp: json['timestamp'] ?? '',
      description: json['description'] ?? '',
      sequence: json['sequence'] ?? 0,
      source: json['source'] ?? 'SYSTEM',
    );
  }
}

class SubOrderModel {
  final int id;
  final int orderId;
  final String vendorStoreName;
  final String packageLabel;
  final String status;
  final String? courierCode;
  final String? courierName;
  final String? trackingNumber;
  final String? trackingUrl;
  final String provisionStatus;
  final String courierReferenceId;
  final String lastError;
  final String paymentStatus;
  final String paymentMethod;
  final String totalAmount;
  final String? shippedAt;
  final String? deliveredAt;
  final String? canceledAt;
  final String? shipByDate;
  final String createdAt;
  final List<OrderItemModel> items;
  final List<ShipmentEventModel> events;

  const SubOrderModel({
    required this.id,
    required this.orderId,
    required this.vendorStoreName,
    required this.packageLabel,
    required this.status,
    this.courierCode,
    this.courierName,
    this.trackingNumber,
    this.trackingUrl,
    required this.provisionStatus,
    required this.courierReferenceId,
    required this.lastError,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalAmount,
    this.shippedAt,
    this.deliveredAt,
    this.canceledAt,
    this.shipByDate,
    required this.createdAt,
    required this.items,
    required this.events,
  });

  factory SubOrderModel.fromJson(Map<String, dynamic> json) {
    return SubOrderModel(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      vendorStoreName: json['vendor_store_name'] ?? '',
      packageLabel: json['package_label'] ?? 'Package',
      status: json['status'] ?? 'PENDING',
      courierCode: json['courier_code']?.toString().isEmpty == true ? null : json['courier_code'],
      courierName: json['courier_name']?.toString().isEmpty == true ? null : json['courier_name'],
      trackingNumber: json['tracking_number']?.toString().isEmpty == true ? null : json['tracking_number'],
      trackingUrl: json['tracking_url']?.toString().isEmpty == true ? null : json['tracking_url'],
      provisionStatus: json['provision_status']?.toString() ?? 'NOT_STARTED',
      courierReferenceId: json['courier_reference_id']?.toString() ?? '',
      lastError: json['last_error']?.toString() ?? '',
      paymentStatus: json['payment_status'] ?? 'UNPAID',
      paymentMethod: json['payment_method'] ?? 'ONLINE',
      totalAmount: json['total_amount']?.toString() ?? '0.00',
      shippedAt: json['shipped_at'],
      deliveredAt: json['delivered_at'],
      canceledAt: json['canceled_at'],
      shipByDate: json['ship_by_date'],
      createdAt: json['created_at'] ?? '',
      items: (json['items'] as List?)
              ?.map((i) => OrderItemModel.fromJson(i))
              .toList() ??
          [],
      events: (json['events'] as List?)
              ?.map((e) => ShipmentEventModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class OrderModel {
  final int id;
  final int? parentOrderId; // Present for vendor sub-orders (order_id)
  final int? couponId;
  final double subtotalAmount;
  final double discountAmount;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String paymentMethod; // ONLINE, COD
  final String? transactionId;
  final String? valId;
  // Present for vendor sub-orders (SubOrderSerializer)
  final String? provisionStatus;
  final String? courierReferenceId;
  final String? lastError;
  final List<OrderItemModel> items;
  final List<SubOrderModel> subOrders;
  final String createdAt;
  final AddressModel? deliveryAddress;

  const OrderModel({
    required this.id,
    this.parentOrderId,
    this.couponId,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    this.transactionId,
    this.valId,
    this.provisionStatus,
    this.courierReferenceId,
    this.lastError,
    required this.items,
    this.subOrders = const [],
    required this.createdAt,
    this.deliveryAddress,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final parsedItems =
        (json['items'] as List?)
            ?.map((item) => OrderItemModel.fromJson(item))
            .toList() ??
        [];

    final parsedSubOrders =
        (json['sub_orders'] as List?)
            ?.map((s) => SubOrderModel.fromJson(s))
            .toList() ??
        [];

    final totalFromJson =
        json.containsKey('total_amount')
            ? (double.tryParse(json['total_amount']?.toString() ?? '') ?? 0.0)
            : null;

    final computedTotal = parsedItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    return OrderModel(
      id: json['id'],
      parentOrderId:
          int.tryParse(json['order_id']?.toString() ?? '') ??
          (json['order_id'] is int ? json['order_id'] as int : null),
      couponId: json['coupon'],
      subtotalAmount:
          double.tryParse(json['subtotal_amount']?.toString() ?? '') ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '') ?? 0.0,
      totalAmount: totalFromJson ?? computedTotal,
      status: json['status'] ?? 'PENDING',
      paymentStatus:
          json['payment_status'] ??
          json['order_payment_status'] ??
          json['paymentStatus'] ??
          'UNPAID',
      paymentMethod:
          json['payment_method'] ??
          json['order_payment_method'] ??
          json['paymentMethod'] ??
          'ONLINE',
      transactionId: json['transaction_id'],
      valId: json['val_id'],
      provisionStatus: json['provision_status']?.toString(),
      courierReferenceId: json['courier_reference_id']?.toString(),
      lastError: json['last_error']?.toString(),
      items: parsedItems,
      subOrders: parsedSubOrders,
      createdAt: json['created_at'] ?? '',
      deliveryAddress: json['delivery_address'] != null
          ? AddressModel.fromJson(json['delivery_address'])
          : null,
    );
  }
}

class OrderItemModel {
  final int id;
  final int? productId;
  final String? productName;
  final int quantity;
  final double price;

  const OrderItemModel({
    required this.id,
    this.productId,
    this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final productDetail = json['product_detail'];
    final titleFromJson = json['product_title'];
    final unitPriceFromJson = json['unit_price'];

    final name =
        (productDetail is Map ? productDetail['name'] : null) ??
        (titleFromJson?.toString().isNotEmpty == true
            ? titleFromJson.toString()
            : null);

    final parsedPrice =
        double.tryParse(json['price']?.toString() ?? '') ??
        double.tryParse(unitPriceFromJson?.toString() ?? '') ??
        0.0;

    return OrderItemModel(
      id: json['id'],
      productId: json['product'],
      productName: name,
      quantity: json['quantity'] ?? 1,
      price: parsedPrice,
    );
  }
}
