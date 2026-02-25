import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;

  OrderProvider({required OrderRepository orderRepository})
    : _orderRepository = orderRepository;

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;
  int? _pendingPaymentOrderId;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get pendingPaymentOrderId => _pendingPaymentOrderId;
  bool get hasPendingPayment => _pendingPaymentOrderId != null;

  void setPendingPaymentOrder(int orderId) {
    _pendingPaymentOrderId = orderId;
    notifyListeners();
  }

  void clearPendingPaymentOrder() {
    if (_pendingPaymentOrderId == null) return;
    _pendingPaymentOrderId = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> validateCoupon(
    String code,
    List<Map<String, dynamic>> items,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _orderRepository.validateCoupon(code, items);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<OrderModel?> placeOrder(
    List<Map<String, dynamic>> items,
    int addressId, {
    String paymentMethod = 'ONLINE',
    String? couponCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final order = await _orderRepository.placeOrder(
        items,
        addressId,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
      );
      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> initiatePayment(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = await _orderRepository.initiatePayment(orderId);
      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancelOrder(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _orderRepository.cancelOrder(orderId);
      // Update locally
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        final existing = _orders[index];
        _orders[index] = OrderModel(
          id: existing.id,
          parentOrderId: existing.parentOrderId,
          couponId: existing.couponId,
          subtotalAmount: existing.subtotalAmount,
          discountAmount: existing.discountAmount,
          totalAmount: existing.totalAmount,
          status: 'CANCELED',
          paymentStatus:
              existing.paymentStatus, // Backend will handle refund logic
          paymentMethod: existing.paymentMethod,
          transactionId: existing.transactionId,
          valId: existing.valId,
          items: existing.items,
          createdAt: existing.createdAt,
          deliveryAddress: existing.deliveryAddress,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadOrders() async {
    await loadOrdersWithLoading(showLoading: true);
  }

  Future<void> loadOrdersWithLoading({required bool showLoading}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _orders = await _orderRepository.getOrderHistory();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }
}
