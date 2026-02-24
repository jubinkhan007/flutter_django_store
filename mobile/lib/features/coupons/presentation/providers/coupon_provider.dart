import 'package:flutter/material.dart';

import '../../data/models/available_coupon_model.dart';
import '../../data/models/coupon_model.dart';
import '../../data/repositories/coupon_repository.dart';


class CouponProvider extends ChangeNotifier {
  final CouponRepository _repository;

  CouponProvider({required CouponRepository repository}) : _repository = repository;

  bool _isLoading = false;
  String? _error;
  List<CouponModel> _globalCoupons = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CouponModel> get globalCoupons => _globalCoupons;

  Future<void> loadGlobalCoupons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _globalCoupons = await _repository.listGlobalCoupons();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<AvailableCouponModel>> fetchAvailableCoupons({
    required List<Map<String, dynamic>> items,
  }) async {
    return _repository.availableCoupons(items: items);
  }
}
