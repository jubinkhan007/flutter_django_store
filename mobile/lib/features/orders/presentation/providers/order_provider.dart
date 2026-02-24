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

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<OrderModel?> placeOrder(List<Map<String, dynamic>> items) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final order = await _orderRepository.placeOrder(items);
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
          totalAmount: existing.totalAmount,
          status: 'CANCELED',
          paymentStatus:
              existing.paymentStatus, // Backend will handle refund logic
          transactionId: existing.transactionId,
          valId: existing.valId,
          items: existing.items,
          createdAt: existing.createdAt,
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _orderRepository.getOrderHistory();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
