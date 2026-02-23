import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepository;

  ProductProvider({required ProductRepository productRepository})
    : _productRepository = productRepository;

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  int? _selectedCategoryId;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedCategoryId => _selectedCategoryId;

  Future<void> loadProducts({int? categoryId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productRepository.getProducts(categoryId: categoryId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _productRepository.getCategories();
      notifyListeners();
    } catch (e) {
      // Categories are optional, don't block the UI
    }
  }

  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
    loadProducts(categoryId: categoryId);
  }
}
