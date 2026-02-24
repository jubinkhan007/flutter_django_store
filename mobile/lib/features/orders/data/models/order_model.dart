class OrderModel {
  final int id;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String? transactionId;
  final String? valId;
  final List<OrderItemModel> items;
  final String createdAt;

  const OrderModel({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.transactionId,
    this.valId,
    required this.items,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      status: json['status'] ?? 'PENDING',
      paymentStatus: json['payment_status'] ?? 'UNPAID',
      transactionId: json['transaction_id'],
      valId: json['val_id'],
      items:
          (json['items'] as List?)
              ?.map((item) => OrderItemModel.fromJson(item))
              .toList() ??
          [],
      createdAt: json['created_at'] ?? '',
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
