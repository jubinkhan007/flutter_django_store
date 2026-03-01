import 'dart:convert';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/app_notification_model.dart';


class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<AppNotificationModel>> list({bool unreadOnly = false}) async {
    final uri = Uri.parse(ApiConfig.notificationsUrl).replace(
      queryParameters: unreadOnly ? {'unread': '1'} : null,
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      final List items = decoded is List ? decoded : (decoded['results'] as List? ?? const []);
      return items.map((e) => AppNotificationModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load notifications');
  }

  Future<int> unreadCount() async {
    final resp = await _apiClient.get(ApiConfig.notificationUnreadCountUrl);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return int.tryParse(data['unread']?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  Future<void> markRead(String id) async {
    final resp = await _apiClient.post(ApiConfig.notificationMarkReadUrl(id));
    if (resp.statusCode != 200) {
      throw Exception('Failed to mark read');
    }
  }

  Future<void> markAllRead() async {
    final resp = await _apiClient.post(ApiConfig.notificationMarkAllReadUrl);
    if (resp.statusCode != 200) {
      throw Exception('Failed to mark all read');
    }
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String deviceId = '',
    String appVersion = '',
  }) async {
    final resp = await _apiClient.post(
      ApiConfig.notificationDeviceRegisterUrl,
      body: {
        'token': token,
        'platform': platform,
        'device_id': deviceId,
        'app_version': appVersion,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to register device token');
    }
  }
}
