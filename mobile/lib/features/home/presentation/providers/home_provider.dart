import 'package:flutter/material.dart';
import '../../data/models/home_feed_model.dart';
import '../../data/repositories/home_repository.dart';

class HomeProvider extends ChangeNotifier {
  final HomeRepository _homeRepository;

  HomeProvider({required HomeRepository homeRepository})
    : _homeRepository = homeRepository;

  HomeFeed? _feed;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;

  HomeFeed? get feed => _feed;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load the home feed from the repository.
  /// [force] if true, reloads even if data is not stale.
  Future<void> loadFeed({bool force = false}) async {
    // Prevent multiple concurrent loads
    if (_isLoading) return;

    // soft auto-refresh: if data is < 5 mins old and not forced, skip
    if (!force && _feed != null && _lastFetch != null) {
      final difference = DateTime.now().difference(_lastFetch!);
      if (difference.inMinutes < 5) return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _feed = await _homeRepository.getHomeFeed();
      _lastFetch = DateTime.now();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually refresh the feed (e.g. from pull-to-refresh)
  Future<void> refresh() => loadFeed(force: true);
}
