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

  // Filter States
  int? _selectedCategoryId;
  String? _searchQuery;
  double? _minPrice;
  double? _maxPrice;
  String? _sortBy;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filter Getters
  int? get selectedCategoryId => _selectedCategoryId;
  String? get searchQuery => _searchQuery;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String? get sortBy => _sortBy;

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productRepository.getProducts(
        query: _searchQuery,
        categoryId: _selectedCategoryId,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
      );
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
    loadProducts();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    loadProducts();
  }

  void setPriceRange(double? min, double? max) {
    _minPrice = min;
    _maxPrice = max;
    loadProducts();
  }

  void setSortBy(String? sort) {
    _sortBy = sort;
    loadProducts();
  }

  void clearFilters() {
    _selectedCategoryId = null;
    _searchQuery = null;
    _minPrice = null;
    _maxPrice = null;
    _sortBy = null;
    loadProducts();
  }
}
