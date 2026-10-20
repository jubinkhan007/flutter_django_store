import 'package:flutter/foundation.dart';

import '../models/loyalty_account_model.dart';
import '../models/loyalty_transaction_model.dart';
import '../repositories/loyalty_repository.dart';

class LoyaltyProvider extends ChangeNotifier {
  final LoyaltyRepository _repository;

  LoyaltyProvider({required LoyaltyRepository repository})
      : _repository = repository;

  LoyaltyAccountModel? _account;
  LoyaltyAccountModel? get account => _account;

  List<LoyaltyTransactionModel> _transactions = [];
  List<LoyaltyTransactionModel> get transactions => _transactions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingTransactions = false;
  bool get isLoadingTransactions => _isLoadingTransactions;

  String? _error;
  String? get error => _error;

  int get pointsBalance => _account?.pointsBalance ?? 0;
  double get pointsValueBdt => _account?.pointsValueBdt ?? 0.0;
  String get tier => _account?.tier ?? 'BRONZE';
  double get tierMultiplier => _account?.tierMultiplier ?? 1.0;

  Future<void> fetchSummary({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _account = await _repository.getSummary();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTransactions() async {
    _isLoadingTransactions = true;
    notifyListeners();

    try {
      _transactions = await _repository.getTransactions();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      fetchSummary(silent: true),
      fetchTransactions(),
    ]);
  }

  Future<Map<String, dynamic>?> quoteRedemption(int points) async {
    try {
      return await _repository.quoteRedemption(points);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }
}
