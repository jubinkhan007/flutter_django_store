import 'package:flutter/material.dart';
import '../../data/models/wishlist_item_model.dart';
import '../../data/repositories/wishlist_repository.dart';

class WishlistProvider extends ChangeNotifier {
  final WishlistRepository _wishlistRepository;

  WishlistProvider({required WishlistRepository wishlistRepository})
    : _wishlistRepository = wishlistRepository;

  List<WishlistItemModel> _items = [];
  bool _isLoading = false;
  String? _error;

  List<WishlistItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get itemCount => _items.length;

  bool isWishlisted(int productId) {
    return _items.any((item) => item.productId == productId);
  }

  Future<void> loadWishlist() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _wishlistRepository.getWishlist();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // It's possible the user is not logged in, ignore or set error.
      _error = e.toString().contains('401') ? null : e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWishlist(
    int productId, {
    Map<String, dynamic>? productDetails,
  }) async {
    // Optimistic UI Update
    final wasWishlisted = isWishlisted(productId);

    if (wasWishlisted) {
      _items.removeWhere((item) => item.productId == productId);
    } else {
      // Add a temporary item for optimistic update if details provided
      if (productDetails != null) {
        _items.insert(
          0,
          WishlistItemModel(
            id: -1, // Temp ID
            productId: productId,
            productName: productDetails['name'] ?? '',
            productPrice: productDetails['price'] ?? 0.0,
            productImage: productDetails['image'],
            productInStock: productDetails['inStock'] ?? true,
            addedAt: DateTime.now().toIso8601String(),
          ),
        );
      }
    }
    notifyListeners();

    try {
      final isNowWishlisted = await _wishlistRepository.toggleWishlist(
        productId,
      );

      // Sync state with truth
      if (wasWishlisted && isNowWishlisted) {
        // Failed to remove, real-load
        await loadWishlist();
      } else if (!wasWishlisted && !isNowWishlisted) {
        // Failed to add, real-load
        await loadWishlist();
      } else if (!wasWishlisted && isNowWishlisted && productDetails == null) {
        // It was added, but we didn't do optimistic insert because missing details. Load.
        await loadWishlist();
      }
    } catch (e) {
      // Revert on error
      _error = 'Failed to update wishlist';
      await loadWishlist();
    }
  }

  void clear() {
    _items = [];
    notifyListeners();
  }
}
