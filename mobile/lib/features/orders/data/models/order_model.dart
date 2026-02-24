import '../../../addresses/data/models/address_model.dart';

class OrderModel {
  final int id;
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
    return OrderModel(
      id: json['id'],
      couponId: json['coupon'],
      subtotalAmount:
          double.tryParse(json['subtotal_amount']?.toString() ?? '') ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '') ?? 0.0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      status: json['status'] ?? 'PENDING',
      paymentStatus: json['payment_status'] ?? 'UNPAID',
      paymentMethod: json['payment_method'] ?? 'ONLINE',
      transactionId: json['transaction_id'],
      valId: json['val_id'],
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItemModel.fromJson(item))
              .toList() ??
          [],
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
    return OrderItemModel(
      id: json['id'],
      productId: json['product'],
      productName: productDetail?['name'],
      quantity: json['quantity'] ?? 1,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }
}
