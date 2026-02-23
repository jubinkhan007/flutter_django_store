import 'package:flutter/material.dart';
import '../../../products/domain/entities/product.dart';

/// Cart item wraps a product with a quantity.
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

/// Cart state management — purely local, no API calls.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.total);
  bool get isEmpty => _items.isEmpty;

  void addToCart(Product product) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Convert cart to the format expected by the order API.
  List<Map<String, dynamic>> toOrderItems() {
    return _items
        .map((item) => {'product': item.product.id, 'quantity': item.quantity})
        .toList();
  }
}
