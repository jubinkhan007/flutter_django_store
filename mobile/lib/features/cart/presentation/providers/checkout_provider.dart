import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../addresses/data/models/address_model.dart';
import '../../../orders/data/models/checkout_quote_model.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/data/repositories/order_repository.dart';
import 'cart_provider.dart';

/// Centralized checkout state controller.
/// Single source of truth for the entire checkout flow:
///   Step 0 → Address selection
///   Step 1 → Payment method
///   Step 2 → Review (server-validated quote) → Place Order
class CheckoutProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;
  final CartProvider _cartProvider;

  CheckoutProvider({
    required OrderRepository orderRepository,
    required CartProvider cartProvider,
  }) : _orderRepository = orderRepository,
       _cartProvider = cartProvider;

  // ── Step state ──
  int _currentStep = 0;
  int get currentStep => _currentStep;

  // ── Address (Step 0) ──
  AddressModel? _selectedAddress;
  AddressModel? get selectedAddress => _selectedAddress;

  // ── Payment (Step 1) ──
  String _paymentMethod = 'ONLINE';
  String get paymentMethod => _paymentMethod;

  // ── Quote (Step 2) ──
  CheckoutQuote? _quote;
  CheckoutQuote? get quote => _quote;

  // ── Placed Order ──
  OrderModel? _placedOrder;
  OrderModel? get placedOrder => _placedOrder;

  // ── Loading / Error ──
  bool _isFetchingQuote = false;
  bool get isFetchingQuote => _isFetchingQuote;

  bool _isPlacingOrder = false;
  bool get isPlacingOrder => _isPlacingOrder;

  bool _isInitiatingPayment = false;
  bool get isInitiatingPayment => _isInitiatingPayment;

  String? _error;
  String? get error => _error;

  // ── Idempotency ──
  String? _idempotencyKey;

  // ── Validation ──
  bool canAdvance(int fromStep) {
    switch (fromStep) {
      case 0:
        return _selectedAddress != null;
      case 1:
        return _paymentMethod.isNotEmpty;
      case 2:
        return _quote != null && !_quote!.hasStockWarnings;
      default:
        return false;
    }
  }

  // ── Step Navigation ──
  void goToStep(int step) {
    if (step < 0 || step > 2) return;
    _currentStep = step;
    _error = null;
    notifyListeners();
  }

  void nextStep() {
    if (!canAdvance(_currentStep)) return;
    if (_currentStep < 2) {
      _currentStep++;
      _error = null;
      notifyListeners();

      // Auto-fetch quote when entering review step
      if (_currentStep == 2) {
        fetchQuote();
      }
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _error = null;
      notifyListeners();
    }
  }

  // ── Address Selection ──
  void selectAddress(AddressModel address) {
    _selectedAddress = address;
    // Invalidate quote when address changes
    _quote = null;
    notifyListeners();
  }

  // ── Payment Selection ──
  void selectPaymentMethod(String method) {
    _paymentMethod = method;
    // Invalidate quote when payment method changes
    _quote = null;
    notifyListeners();
  }

  // ── Server-side Quote ──
  Future<void> fetchQuote() async {
    if (_selectedAddress == null) return;

    _isFetchingQuote = true;
    _error = null;
    notifyListeners();

    try {
      _quote = await _orderRepository.fetchQuote(
        items: _cartProvider.toOrderItems(),
        addressId: _selectedAddress!.id,
        couponCode: _cartProvider.couponCode,
        paymentMethod: _paymentMethod,
      );
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _quote = null;
    } finally {
      _isFetchingQuote = false;
      notifyListeners();
    }
  }

  // ── Place Order ──
  Future<bool> placeOrder() async {
    if (_selectedAddress == null || _isPlacingOrder) return false;

    _isPlacingOrder = true;
    _error = null;
    // Generate idempotency key if not already set
    _idempotencyKey ??= const Uuid().v4();
    notifyListeners();

    try {
      _placedOrder = await _orderRepository.placeOrder(
        _cartProvider.toOrderItems(),
        _selectedAddress!.id,
        paymentMethod: _paymentMethod,
        couponCode: _cartProvider.couponCode,
        idempotencyKey: _idempotencyKey,
      );

      // Clear cart on success
      _cartProvider.clear();
      _isPlacingOrder = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isPlacingOrder = false;
      notifyListeners();
      return false;
    }
  }

  // ── Payment Initiation (Online) ──
  Future<String?> initiatePayment() async {
    if (_placedOrder == null) return null;

    _isInitiatingPayment = true;
    _error = null;
    notifyListeners();

    try {
      final url = await _orderRepository.initiatePayment(_placedOrder!.id);
      _isInitiatingPayment = false;
      notifyListeners();
      return url;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isInitiatingPayment = false;
      notifyListeners();
      return null;
    }
  }

  // ── Payment Status Polling ──
  Future<OrderModel?> refreshOrderStatus() async {
    if (_placedOrder == null) return null;

    try {
      final updated = await _orderRepository.getOrderDetail(_placedOrder!.id);
      _placedOrder = updated;
      notifyListeners();
      return updated;
    } catch (_) {
      return null;
    }
  }

  // ── Reset ──
  void reset() {
    _currentStep = 0;
    _selectedAddress = null;
    _paymentMethod = 'ONLINE';
    _quote = null;
    _placedOrder = null;
    _isFetchingQuote = false;
    _isPlacingOrder = false;
    _isInitiatingPayment = false;
    _error = null;
    _idempotencyKey = null;
    notifyListeners();
  }
}
