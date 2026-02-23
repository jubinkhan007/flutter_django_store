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

  Future<bool> placeOrder(List<Map<String, dynamic>> items) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _orderRepository.placeOrder(items);
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
