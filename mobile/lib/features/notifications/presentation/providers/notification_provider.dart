import 'package:flutter/material.dart';

import '../../data/models/app_notification_model.dart';
import '../../data/repositories/notification_repository.dart';


class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;

  NotificationProvider({required NotificationRepository repository})
      : _repository = repository;

  List<AppNotificationModel> _items = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<AppNotificationModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _repository.unreadCount();
      notifyListeners();
    } catch (_) {
      // Ignore (e.g., not logged in yet).
    }
  }

  Future<void> load({bool unreadOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _repository.list(unreadOnly: unreadOnly);
      _unreadCount = _items.where((n) => !n.isRead).length;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markRead(id);
      _items = _items
          .map((n) => n.id == id ? AppNotificationModel(
                id: n.id,
                title: n.title,
                body: n.body,
                type: n.type,
                category: n.category,
                data: n.data,
                deeplink: n.deeplink,
                isRead: true,
                createdAt: n.createdAt,
              ) : n)
          .toList();
      await refreshUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      _items = _items
          .map((n) => AppNotificationModel(
                id: n.id,
                title: n.title,
                body: n.body,
                type: n.type,
                category: n.category,
                data: n.data,
                deeplink: n.deeplink,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
      await refreshUnreadCount();
      notifyListeners();
    } catch (_) {}
  }
}

