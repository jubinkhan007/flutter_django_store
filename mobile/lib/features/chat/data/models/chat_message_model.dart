class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String senderType; // 'CUSTOMER' or 'VENDOR'
  final String messageType; // 'TEXT', 'IMAGE', 'PRODUCT', 'ORDER'
  final String text;
  final String? image;
  final String? imageUrl;
  final bool isRead;
  final bool isMe;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.messageType,
    required this.text,
    this.image,
    this.imageUrl,
    required this.isRead,
    required this.isMe,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      conversationId: json['conversation'] as int? ?? 0,
      senderId: json['sender'] as int? ?? 0,
      senderName: json['sender_name'] as String? ?? '',
      senderType: json['sender_type'] as String? ?? 'CUSTOMER',
      messageType: json['message_type'] as String? ?? 'TEXT',
      text: json['text'] as String? ?? '',
      image: json['image'] as String?,
      imageUrl: json['image_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isMe: json['is_me'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation': conversationId,
      'sender': senderId,
      'sender_name': senderName,
      'sender_type': senderType,
      'message_type': messageType,
      'text': text,
      'image': image,
      'image_url': imageUrl,
      'is_read': isRead,
      'is_me': isMe,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
