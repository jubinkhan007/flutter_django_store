class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String category;
  final Map<String, dynamic> data;
  final String deeplink;
  final bool isRead;
  final DateTime createdAt;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.category,
    required this.data,
    required this.deeplink,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString() ?? '';
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      data: (json['data'] is Map<String, dynamic>)
          ? (json['data'] as Map<String, dynamic>)
          : <String, dynamic>{},
      deeplink: json['deeplink']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(created) ?? DateTime.now(),
    );
  }
}

