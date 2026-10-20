class LoyaltyTransactionModel {
  final int id;
  final String transactionType;
  final int points;
  final int balanceAfter;
  final int? orderId;
  final String description;
  final DateTime createdAt;

  const LoyaltyTransactionModel({
    required this.id,
    required this.transactionType,
    required this.points,
    required this.balanceAfter,
    this.orderId,
    required this.description,
    required this.createdAt,
  });

  bool get isEarn => transactionType == 'EARN';
  bool get isRedeem => transactionType == 'REDEEM';
  bool get isRefund => transactionType == 'REFUND';

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionModel(
      id: json['id'] as int? ?? 0,
      transactionType: json['transaction_type']?.toString() ?? 'EARN',
      points: json['points'] as int? ?? 0,
      balanceAfter: json['balance_after'] as int? ?? 0,
      orderId: json['order_id'] as int?,
      description: json['description']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_type': transactionType,
      'points': points,
      'balance_after': balanceAfter,
      'order_id': orderId,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
