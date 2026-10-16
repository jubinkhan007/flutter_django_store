import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetches all conversations visible to the authenticated user.
  Future<List<ChatConversationModel>> getConversations() async {
    final resp = await _apiClient.get(ApiConfig.chatConversationsUrl);
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data
          .map((e) => ChatConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load conversations (${resp.statusCode})');
  }

  /// Starts or retrieves an active conversation with a vendor.
  Future<ChatConversationModel> startConversation({
    required int vendorId,
    int? productId,
    int? orderId,
    String? message,
  }) async {
    final payload = <String, dynamic>{
      'vendor_id': vendorId,
      if (productId != null) 'product_id': productId,
      if (orderId != null) 'order_id': orderId,
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
    };

    final resp = await _apiClient.post(
      ApiConfig.chatStartConversationUrl,
      body: payload,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return ChatConversationModel.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['detail'] ?? 'Failed to start conversation');
  }

  /// Fetches conversation details and messages. Supports `afterId` for polling.
  Future<ChatConversationModel> getConversationDetail(
    int conversationId, {
    int? afterId,
  }) async {
    final url = ApiConfig.chatConversationDetailUrl(
      conversationId,
      afterId: afterId,
    );
    final resp = await _apiClient.get(url);
    if (resp.statusCode == 200) {
      return ChatConversationModel.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to load conversation details (${resp.statusCode})');
  }

  /// Sends a message into a conversation (supports optional image).
  Future<ChatMessageModel> sendMessage(
    int conversationId, {
    String text = '',
    String? imagePath,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (imagePath == null || imagePath.isEmpty)) {
      throw Exception('Either text or image must be provided');
    }

    final url = ApiConfig.chatSendMessageUrl(conversationId);

    if (imagePath == null || imagePath.isEmpty) {
      final resp = await _apiClient.post(
        url,
        body: {'text': trimmed, 'message_type': 'TEXT'},
      );
      if (resp.statusCode == 201) {
        return ChatMessageModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
      final err = jsonDecode(resp.body);
      throw Exception(err['detail'] ?? 'Failed to send message');
    }

    // Multipart upload with attachment
    final files = <http.MultipartFile>[
      await http.MultipartFile.fromPath('image', imagePath),
    ];
    final fields = <String, String>{
      if (trimmed.isNotEmpty) 'text': trimmed,
      'message_type': 'IMAGE',
    };

    final streamedResp = await _apiClient.postMultipart(
      url,
      fields: fields,
      files: files,
    );
    final body = await streamedResp.stream.bytesToString();
    if (streamedResp.statusCode == 201) {
      return ChatMessageModel.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    }
    final err = jsonDecode(body);
    throw Exception(err['detail'] ?? 'Failed to send image message');
  }

  /// Marks unread messages in the conversation as read.
  Future<void> markAsRead(int conversationId) async {
    final url = ApiConfig.chatMarkReadUrl(conversationId);
    await _apiClient.post(url, body: {});
  }

  /// Gets the total unread chat messages for the current user.
  Future<int> getUnreadCount() async {
    try {
      final resp = await _apiClient.get(ApiConfig.chatUnreadCountUrl);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['unread_count'] as int? ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
