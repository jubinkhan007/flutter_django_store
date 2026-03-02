import 'package:flutter/material.dart';

import '../../data/models/return_request_model.dart';
import '../../data/repositories/return_repository.dart';


class ReturnProvider extends ChangeNotifier {
  final ReturnRepository _repository;

  ReturnProvider({required ReturnRepository repository}) : _repository = repository;

  bool _isLoading = false;
  String? _error;
  List<ReturnRequestModel> _myReturns = [];
  List<ReturnRequestModel> _vendorReturns = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ReturnRequestModel> get myReturns => _myReturns;
  List<ReturnRequestModel> get vendorReturns => _vendorReturns;

  Future<void> loadMyReturns() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myReturns = await _repository.listMyReturns();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ReturnRequestModel?> escalateReturn(int returnId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.escalateReturn(returnId);
      _myReturns = _myReturns.map((r) => r.id == returnId ? updated : r).toList();
      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<List<ReturnRequestModel>?> createReturn({
    required int orderId,
    required String requestType,
    required String reason,
    required String fulfillment,
    required String refundMethodPreference,
    required List<Map<String, dynamic>> items,
    String reasonDetails = '',
    String customerNote = '',
    List<String> imagePaths = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _repository.createReturn(
        orderId: orderId,
        requestType: requestType,
        reason: reason,
        fulfillment: fulfillment,
        refundMethodPreference: refundMethodPreference,
        items: items,
        reasonDetails: reasonDetails,
        customerNote: customerNote,
      );

      var updatedCreated = created;
      if (created.isNotEmpty && imagePaths.isNotEmpty) {
        final replacements = <int, ReturnRequestModel>{};
        for (final rr in created) {
          try {
            final updated = await _repository.uploadReturnImages(
              returnId: rr.id,
              imagePaths: imagePaths,
            );
            replacements[rr.id] = updated;
          } catch (e) {
            _error = 'Return submitted, but image upload failed: ${e.toString().replaceAll('Exception: ', '')}';
          }
        }
        updatedCreated =
            created.map((r) => replacements[r.id] ?? r).toList();
      }

      _isLoading = false;
      notifyListeners();
      return updatedCreated;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadVendorReturns() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vendorReturns = await _repository.listVendorReturns();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> vendorApprove(int returnId, {String note = ''}) async {
    return vendorApproveWithDetails(returnId, note: note);
  }

  Future<bool> vendorApproveWithDetails(
    int returnId, {
    String note = '',
    DateTime? pickupWindowStart,
    DateTime? pickupWindowEnd,
    String dropoffInstructions = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.vendorApproveWithDetails(
        returnId,
        note: note,
        pickupWindowStart: pickupWindowStart,
        pickupWindowEnd: pickupWindowEnd,
        dropoffInstructions: dropoffInstructions,
      );
      _vendorReturns = _vendorReturns.map((r) => r.id == returnId ? updated : r).toList();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> vendorReject(int returnId, {String note = ''}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.vendorReject(returnId, note: note);
      _vendorReturns = _vendorReturns.map((r) => r.id == returnId ? updated : r).toList();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> vendorMarkReceived(int returnId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.vendorMarkReceived(returnId);
      _vendorReturns = _vendorReturns.map((r) => r.id == returnId ? updated : r).toList();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> vendorRefundToWallet(int returnId) async {
    return vendorInitiateRefund(returnId, method: 'WALLET');
  }

  Future<bool> vendorInitiateRefund(
    int returnId, {
    required String method,
    double? amount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.vendorInitiateRefund(
        returnId,
        method: method,
        amount: amount,
      );
      _vendorReturns = _vendorReturns.map((r) => r.id == returnId ? updated : r).toList();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> vendorCompleteOriginalRefund(
    int returnId, {
    String reference = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _repository.vendorCompleteOriginalRefund(
        returnId,
        reference: reference,
      );
      _vendorReturns = _vendorReturns.map((r) => r.id == returnId ? updated : r).toList();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
