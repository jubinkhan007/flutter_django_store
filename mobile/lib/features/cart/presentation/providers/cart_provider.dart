import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/api_config.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/entities/variant.dart';

class CartItem {
  final Product product;
  final ProductVariant? variant;
  int quantity;

  CartItem({required this.product, this.variant, this.quantity = 1});

  double get effectivePrice => variant?.effectivePrice ?? product.effectivePrice;

  double get total => effectivePrice * quantity;
}

class CartProvider extends ChangeNotifier {
  static const _storageKey = 'cart_v1';

  final List<CartItem> _items = [];
  String? _couponCode;
  double _couponDiscount = 0.0;

  CartProvider() {
    _restoreFromStorage();
  }

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Subtotal (before coupons).
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.total);

  bool get isEmpty => _items.isEmpty;
  String? get couponCode => _couponCode;
  double get couponDiscount => _couponDiscount;

  Future<void> _restoreFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final items = (decoded['items'] as List?) ?? const [];
      _items.clear();
      for (final it in items) {
        if (it is! Map) continue;
        final productJson = it['product'];
        if (productJson is! Map) continue;
        final qty = int.tryParse(it['quantity']?.toString() ?? '') ?? 1;
        final product = _productFromStorage(productJson.cast<String, dynamic>());
        if (product.id <= 0) continue;
        
        ProductVariant? variant;
        if (it['variant'] != null && it['variant'] is Map) {
            variant = ProductVariant.fromJson(it['variant'].cast<String, dynamic>());
        }

        _items.add(CartItem(product: product, variant: variant, quantity: qty.clamp(1, 999)));
      }

      final coupon = decoded['coupon'];
      if (coupon is Map) {
        _couponCode = coupon['code']?.toString();
        _couponDiscount =
            double.tryParse(coupon['discount']?.toString() ?? '') ?? 0.0;
      } else {
        _couponCode = null;
        _couponDiscount = 0.0;
      }

      notifyListeners();
    } catch (_) {
      // Ignore corrupted storage.
    }
  }

  Product _productFromStorage(Map<String, dynamic> json) {
    final rawImage = json['image']?.toString();
    final resolvedImage = (rawImage == null || rawImage.trim().isEmpty)
        ? null
        : ApiConfig.resolveUrl(rawImage);

    return Product(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      vendorId: json['vendorId'] == null
          ? null
          : int.tryParse(json['vendorId'].toString()),
      categoryId: json['categoryId'] == null
          ? null
          : int.tryParse(json['categoryId'].toString()),
      name: (json['name'] ?? 'Product').toString(),
      description: (json['description'] ?? '').toString(),
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      salePrice: json['salePrice'] != null
          ? double.tryParse(json['salePrice'].toString())
          : null,
      stockQuantity:
          int.tryParse(json['stockQuantity']?.toString() ?? '') ?? 0,
      image: resolvedImage,
      isAvailable: json['isAvailable'] == null ? true : json['isAvailable'] == true,
      inStock: json['inStock'] == null
          ? ((int.tryParse(json['stockQuantity']?.toString() ?? '') ?? 0) > 0)
          : json['inStock'] == true,
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> _productToStorage(Product p) {
    return {
      'id': p.id,
      'vendorId': p.vendorId,
      'categoryId': p.categoryId,
      'name': p.name,
      'description': p.description,
      'price': p.price,
      'salePrice': p.salePrice,
      'stockQuantity': p.stockQuantity,
      'image': p.image,
      'isAvailable': p.isAvailable,
      'inStock': p.inStock,
      'createdAt': p.createdAt,
    };
  }
  
  Map<String, dynamic> _variantToStorage(ProductVariant v) {
    return {
        'id': v.id,
        'sku': v.sku,
        'barcode': v.barcode,
        'price_override': v.priceOverride,
        'effective_price': v.effectivePrice,
        'stock_on_hand': v.stockOnHand,
        'reserved_stock': v.reservedStock,
        'low_stock_threshold': v.lowStockThreshold,
        'stock_available': v.stockAvailable,
        'is_active': v.isActive,
        'option_value_ids': v.optionValueIds,
    };
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'items': _items
            .map(
              (e) => {
                'product': _productToStorage(e.product),
                'variant': e.variant != null ? _variantToStorage(e.variant!) : null,
                'quantity': e.quantity,
              },
            )
            .toList(),
        'coupon': _couponCode == null
            ? null
            : {
                'code': _couponCode,
                'discount': _couponDiscount,
              },
      };
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {
      // Best-effort persistence.
    }
  }

  void addToCart(Product product, {ProductVariant? variant}) {
    final existingIndex = _items.indexWhere(
        (item) => item.product.id == product.id && item.variant?.id == variant?.id
    );
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(product: product, variant: variant));
    }

    // Avoid stale coupon discounts if cart changes.
    if (_couponCode != null) {
      clearCoupon();
      return;
    }

    notifyListeners();
    _saveToStorage();
  }

  void removeFromCart(int productId, {int? variantId}) {
    _items.removeWhere((item) => item.product.id == productId && item.variant?.id == variantId);
    if (_items.isEmpty) {
      clearCoupon();
      return;
    }
    if (_couponCode != null) {
      clearCoupon();
      return;
    }
    notifyListeners();
    _saveToStorage();
  }

  void updateQuantity(int productId, int quantity, {int? variantId}) {
    final index = _items.indexWhere((item) => item.product.id == productId && item.variant?.id == variantId);
    if (index < 0) return;

    if (quantity <= 0) {
      _items.removeAt(index);
      if (_items.isEmpty) {
        clearCoupon();
        return;
      }
    } else {
      _items[index].quantity = quantity;
    }

    if (_couponCode != null) {
      clearCoupon();
      return;
    }

    notifyListeners();
    _saveToStorage();
  }

  void clear() {
    _items.clear();
    _couponCode = null;
    _couponDiscount = 0.0;
    notifyListeners();
    _saveToStorage();
  }

  void applyCoupon({required String code, required double discountAmount}) {
    _couponCode = code;
    _couponDiscount = discountAmount < 0 ? 0.0 : discountAmount;
    notifyListeners();
    _saveToStorage();
  }

  void clearCoupon() {
    _couponCode = null;
    _couponDiscount = 0.0;
    notifyListeners();
    _saveToStorage();
  }

  List<Map<String, dynamic>> toOrderItems() {
    return _items
        .map((item) => {
            'product': item.product.id,
            'variant': item.variant?.id,
            'quantity': item.quantity
        })
        .toList();
  }
}
