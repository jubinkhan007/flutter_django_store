import '../../../addresses/data/models/address_model.dart';

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
  final List<OrderItemModel> items;
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
    required this.items,
    required this.createdAt,
    this.deliveryAddress,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final parsedItems =
        (json['items'] as List?)
            ?.map((item) => OrderItemModel.fromJson(item))
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
      items: parsedItems,
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
