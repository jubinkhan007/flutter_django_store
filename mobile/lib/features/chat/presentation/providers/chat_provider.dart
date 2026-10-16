import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;

  ChatProvider({required ChatRepository repository}) : _repository = repository;

  List<ChatConversationModel> _conversations = [];
  ChatConversationModel? _activeConversation;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  int _unreadTotal = 0;
  Timer? _pollingTimer;

  List<ChatConversationModel> get conversations => _conversations;
  ChatConversationModel? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  int get unreadTotal => _unreadTotal;

  /// Loads all conversation threads for customer or vendor.
  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _repository.getConversations();
      await refreshUnreadCount();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the total unread badge counter.
  Future<void> refreshUnreadCount() async {
    try {
      _unreadTotal = await _repository.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  /// Opens a conversation, loads all messages, marks as read, and starts polling.
  Future<void> openConversation(int conversationId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeConversation = await _repository.getConversationDetail(conversationId);
      await _repository.markAsRead(conversationId);
      
      // Update local unread counts
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      }
      await refreshUnreadCount();

      // Start periodic polling
      _startPolling(conversationId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Starts or gets an existing conversation with a vendor.
  Future<ChatConversationModel?> startConversationWithVendor({
    required int vendorId,
    int? productId,
    int? orderId,
    String? message,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final conv = await _repository.startConversation(
        vendorId: vendorId,
        productId: productId,
        orderId: orderId,
        message: message,
      );
      _activeConversation = conv;
      _startPolling(conv.id);
      await loadConversations();
      return conv;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a message into the active conversation.
  Future<bool> sendMessage(String text, {String? imagePath}) async {
    final conv = _activeConversation;
    if (conv == null) return false;

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newMsg = await _repository.sendMessage(
        conv.id,
        text: text,
        imagePath: imagePath,
      );

      // Append new message to active conversation
      final updatedMessages = List<ChatMessageModel>.from(conv.messages)..add(newMsg);
      final updatedPreview = newMsg.text.isNotEmpty ? newMsg.text : 'Sent an attachment';

      _activeConversation = conv.copyWith(
        messages: updatedMessages,
        lastMessagePreview: updatedPreview,
        lastMessageAt: newMsg.createdAt,
      );

      // Also update conversations list
      final idx = _conversations.indexWhere((c) => c.id == conv.id);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(
          lastMessagePreview: updatedPreview,
          lastMessageAt: newMsg.createdAt,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Starts lightweight polling every 4 seconds for new incoming messages.
  void _startPolling(int conversationId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _pollNewMessages(conversationId);
    });
  }

  /// Polls for messages newer than the highest current message ID.
  Future<void> _pollNewMessages(int conversationId) async {
    final current = _activeConversation;
    if (current == null || current.id != conversationId) {
      _pollingTimer?.cancel();
      return;
    }

    final int? afterId = current.messages.isNotEmpty ? current.messages.last.id : null;

    try {
      final updated = await _repository.getConversationDetail(conversationId, afterId: afterId);
      if (updated.messages.isNotEmpty) {
        final existingIds = current.messages.map((m) => m.id).toSet();
        final newMsgs = updated.messages.where((m) => !existingIds.contains(m.id)).toList();

        if (newMsgs.isNotEmpty) {
          final mergedMessages = List<ChatMessageModel>.from(current.messages)..addAll(newMsgs);
          _activeConversation = current.copyWith(
            messages: mergedMessages,
            lastMessagePreview: newMsgs.last.text.isNotEmpty ? newMsgs.last.text : 'Sent an attachment',
            lastMessageAt: newMsgs.last.createdAt,
          );
          await _repository.markAsRead(conversationId);
          notifyListeners();
        }
      }
    } catch (_) {
      // Silent error during background poll
    }
  }

  /// Closes the active conversation and stops polling.
  void closeConversation() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activeConversation = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
