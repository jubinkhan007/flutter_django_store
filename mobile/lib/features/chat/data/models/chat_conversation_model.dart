import 'chat_message_model.dart';

class ChatProductSummary {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;

  const ChatProductSummary({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  factory ChatProductSummary.fromJson(Map<String, dynamic> json) {
    return ChatProductSummary(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class ChatOrderSummary {
  final int id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final DateTime createdAt;

  const ChatOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
  });

  factory ChatOrderSummary.fromJson(Map<String, dynamic> json) {
    return ChatOrderSummary(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChatConversationModel {
  final int id;
  final int vendorId;
  final String vendorName;
  final String? vendorLogo;
  final int customerId;
  final String customerName;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
  final int unreadCount;
  final ChatProductSummary? product;
  final ChatOrderSummary? order;
  final List<ChatMessageModel> messages;

  const ChatConversationModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.vendorLogo,
    required this.customerId,
    required this.customerName,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
    this.product,
    this.order,
    this.messages = const [],
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    List<ChatMessageModel> msgs = [];
    if (json['messages'] is List) {
      msgs = (json['messages'] as List)
          .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return ChatConversationModel(
      id: json['id'] as int,
      vendorId: json['vendor_id'] as int? ?? 0,
      vendorName: json['vendor_name'] as String? ?? 'Vendor',
      vendorLogo: json['vendor_logo'] as String?,
      customerId: json['customer_id'] as int? ?? 0,
      customerName: json['customer_name'] as String? ?? 'Customer',
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unread_count'] as int? ?? 0,
      product: json['product'] != null
          ? ChatProductSummary.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      order: json['order'] != null
          ? ChatOrderSummary.fromJson(json['order'] as Map<String, dynamic>)
          : null,
      messages: msgs,
    );
  }

  ChatConversationModel copyWith({
    int? id,
    int? vendorId,
    String? vendorName,
    String? vendorLogo,
    int? customerId,
    String? customerName,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    int? unreadCount,
    ChatProductSummary? product,
    ChatOrderSummary? order,
    List<ChatMessageModel>? messages,
  }) {
    return ChatConversationModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorLogo: vendorLogo ?? this.vendorLogo,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      product: product ?? this.product,
      order: order ?? this.order,
      messages: messages ?? this.messages,
    );
  }
}
