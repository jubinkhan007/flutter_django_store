import 'package:flutter/material.dart';

import '../../data/models/cb_models.dart';
import '../../data/repositories/crossborder_repository.dart';

class CrossBorderProvider extends ChangeNotifier {
  final CrossBorderRepository _repo;

  CrossBorderProvider({required CrossBorderRepository repository})
    : _repo = repository;

  // ── Catalog ──
  List<CrossBorderProduct> _products = [];
  bool _productsLoading = false;
  String? _productsError;
  List<CbShippingConfig> _shippingConfigs = [];

  List<CrossBorderProduct> get products => _products;
  bool get productsLoading => _productsLoading;
  String? get productsError => _productsError;
  List<CbShippingConfig> get shippingConfigs => _shippingConfigs;

  // ── My Requests ──
  List<CrossBorderOrderRequest> _myRequests = [];
  bool _requestsLoading = false;
  String? _requestsError;

  List<CrossBorderOrderRequest> get myRequests => _myRequests;
  bool get requestsLoading => _requestsLoading;
  String? get requestsError => _requestsError;

  // ── Active Request Detail ──
  CrossBorderOrderRequest? _activeRequest;
  bool _activeLoading = false;

  CrossBorderOrderRequest? get activeRequest => _activeRequest;
  bool get activeLoading => _activeLoading;

  // ── Async Action ──
  bool _actionLoading = false;
  String? _actionError;

  bool get actionLoading => _actionLoading;
  String? get actionError => _actionError;

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  // ── Link Preview ──

  CbLinkPreview? _linkPreview;
  bool _previewLoading = false;
  String? _previewError;

  CbLinkPreview? get linkPreview => _linkPreview;
  bool get previewLoading => _previewLoading;
  String? get previewError => _previewError;

  void clearLinkPreview() {
    _linkPreview = null;
    _previewError = null;
    notifyListeners();
  }

  Future<CbLinkPreview?> fetchLinkPreview(String url) async {
    _previewLoading = true;
    _previewError = null;
    _linkPreview = null;
    notifyListeners();
    try {
      _linkPreview = await _repo.fetchLinkPreview(url);
      return _linkPreview;
    } catch (e) {
      _previewError = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _previewLoading = false;
      notifyListeners();
    }
  }

  // ── Catalog ──

  Future<void> loadCatalog() async {
    _productsLoading = true;
    _productsError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.fetchProducts(),
        _repo.fetchShippingConfigs(),
      ]);
      _products = results[0] as List<CrossBorderProduct>;
      _shippingConfigs = results[1] as List<CbShippingConfig>;
    } catch (e) {
      _productsError = e.toString();
    } finally {
      _productsLoading = false;
      notifyListeners();
    }
  }

  // ── My Requests ──

  Future<void> loadMyRequests() async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();
    try {
      _myRequests = await _repo.fetchMyRequests();
    } catch (e) {
      _requestsError = e.toString();
    } finally {
      _requestsLoading = false;
      notifyListeners();
    }
  }

  Future<void> openRequest(int id) async {
    _activeLoading = true;
    notifyListeners();
    try {
      _activeRequest = await _repo.fetchRequestDetail(id);
    } catch (_) {
      // silent – caller checks activeRequest
    } finally {
      _activeLoading = false;
      notifyListeners();
    }
  }

  // ── Create Request (quote) ──

  Future<CrossBorderOrderRequest?> createRequest({
    int? productId,
    String? sourceUrl,
    required String marketplace,
    required String variantNotes,
    required int quantity,
    required String shippingMethod,
    double? itemPriceForeign,
    String? currency,
    double? estimatedWeightKg,
  }) async {
    _actionLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      final req = await _repo.createRequest(
        productId: productId,
        sourceUrl: sourceUrl,
        marketplace: marketplace,
        variantNotes: variantNotes,
        quantity: quantity,
        shippingMethod: shippingMethod,
        itemPriceForeign: itemPriceForeign,
        currency: currency,
        estimatedWeightKg: estimatedWeightKg,
      );
      _activeRequest = req;
      return req;
    } catch (e) {
      _actionError = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Checkout ──

  Future<CrossBorderOrderRequest?> checkout({
    required int requestId,
    required int addressId,
    required bool customsPolicyAcknowledged,
  }) async {
    _actionLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      final req = await _repo.checkout(
        requestId: requestId,
        addressId: addressId,
        customsPolicyAcknowledged: customsPolicyAcknowledged,
      );
      _activeRequest = req;
      await loadMyRequests();
      return req;
    } catch (e) {
      _actionError = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  // ── Mark Received ──

  Future<bool> markReceived(int requestId) async {
    _actionLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      await _repo.markReceived(requestId);
      await openRequest(requestId);
      await loadMyRequests();
      return true;
    } catch (e) {
      _actionError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }
}
