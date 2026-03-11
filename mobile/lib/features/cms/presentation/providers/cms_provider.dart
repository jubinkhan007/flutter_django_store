import 'package:flutter/material.dart';

import '../../data/models/cms_models.dart';
import '../../data/repositories/cms_repository.dart';

class CmsProvider extends ChangeNotifier {
  final CmsRepository _repository;

  CmsProvider({required CmsRepository repository}) : _repository = repository;

  CmsBootstrap? _bootstrap;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;

  CmsBootstrap? get bootstrap => _bootstrap;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  bool get hasBootstrap => _bootstrap != null;

  Future<void> loadBootstrap({bool forceRefresh = false}) async {
    if (_isRefreshing) return;

    if (!forceRefresh && _bootstrap == null) {
      final cached = await _repository.loadCachedBootstrap();
      if (cached != null) {
        _bootstrap = cached;
        notifyListeners();
      }
    }

    _isLoading = _bootstrap == null;
    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      final remote = await _repository.fetchBootstrap();
      if (_bootstrap == null || _bootstrap!.updatedAt != remote.updatedAt) {
        _bootstrap = remote;
        await _repository.cacheBootstrap(remote);
      }
    } catch (e) {
      if (_bootstrap == null) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<CmsPageDetail> fetchPage({String? slug, String? pageType}) {
    return _repository.fetchPage(slug: slug, pageType: pageType);
  }

  String? stringSetting(String key) => _bootstrap?.stringSetting(key);

  bool boolSetting(String key, {bool fallback = false}) =>
      _bootstrap?.boolSetting(key, fallback: fallback) ?? fallback;

  List<CmsBanner> bannersForPosition(String position) =>
      _bootstrap?.bannersForPosition(position) ?? const [];

  CmsPageSummary? pageByType(String pageType) => _bootstrap?.pageByType(pageType);
}
