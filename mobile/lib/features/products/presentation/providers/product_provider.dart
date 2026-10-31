import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/search_suggestion.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/models/product_facets_model.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepository;

  ProductProvider({required ProductRepository productRepository})
    : _productRepository = productRepository;

  List<Product> _products = [];
  List<Category> _categories = [];
  List<SearchSuggestion> _suggestions = [];
  ProductFacets? _facets;
  List<String> _recentSearches = [];
  List<String> _trendingSearches = [];
  bool _isLoading = false;
  bool _isFacetsLoading = false;
  bool _isSuggestionsLoading = false;
  String? _error;

  // Filter States
  int? _selectedCategoryId;
  String? _searchQuery;
  double? _minPrice;
  double? _maxPrice;
  String? _sortBy;
  List<String> _selectedBrands = [];
  double? _minRating;
  int? _minDiscount;
  bool _inStockOnly = false;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  List<SearchSuggestion> get suggestions => _suggestions;
  ProductFacets? get facets => _facets;
  List<String> get recentSearches => _recentSearches;
  List<String> get trendingSearches => _trendingSearches;
  bool get isLoading => _isLoading;
  bool get isFacetsLoading => _isFacetsLoading;
  bool get isSuggestionsLoading => _isSuggestionsLoading;
  String? get error => _error;

  // Filter Getters
  int? get selectedCategoryId => _selectedCategoryId;
  String? get searchQuery => _searchQuery;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String? get sortBy => _sortBy;
  List<String> get selectedBrands => _selectedBrands;
  double? get minRating => _minRating;
  int? get minDiscount => _minDiscount;
  bool get inStockOnly => _inStockOnly;

  int get activeFilterCount {
    int count = 0;
    if (_selectedCategoryId != null) count++;
    if (_minPrice != null || _maxPrice != null) count++;
    if (_selectedBrands.isNotEmpty) count += _selectedBrands.length;
    if (_minRating != null) count++;
    if (_minDiscount != null) count++;
    if (_inStockOnly) count++;
    if (_sortBy != null && _sortBy!.isNotEmpty) count++;
    return count;
  }

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
        brands: _selectedBrands.isNotEmpty ? _selectedBrands : null,
        minRating: _minRating,
        minDiscount: _minDiscount,
        inStock: _inStockOnly ? true : null,
      );
      _isLoading = false;
      notifyListeners();

      // Also refresh facets in background when filters/search changes
      loadFacets();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFacets() async {
    _isFacetsLoading = true;
    try {
      _facets = await _productRepository.getFacets(
        query: _searchQuery,
        categoryId: _selectedCategoryId,
      );
    } catch (_) {}
    _isFacetsLoading = false;
    notifyListeners();
  }

  Future<void> loadSearchHistory() async {
    try {
      final historyMap = await _productRepository.getSearchHistory();
      _recentSearches = historyMap['recent'] ?? [];
      _trendingSearches = historyMap['trending'] ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    notifyListeners();
    await _productRepository.clearSearchHistory();
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _productRepository.getCategories();
      notifyListeners();
    } catch (e) {
      // Categories are optional, don't block the UI
    }
  }

  Future<Product> getProductDetail(int id) {
    return _productRepository.getProductDetail(id);
  }

  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadProducts();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    _suggestions = [];
    if (query != null && query.trim().length >= 2) {
      _productRepository.saveSearchQuery(query.trim());
      if (!_recentSearches.contains(query.trim())) {
        _recentSearches.insert(0, query.trim());
      }
    }
    loadProducts();
  }

  void applyCategoryShortcut(int? categoryId) {
    _selectedCategoryId = categoryId;
    _searchQuery = null;
    _minPrice = null;
    _maxPrice = null;
    _sortBy = null;
    _selectedBrands.clear();
    _minRating = null;
    _minDiscount = null;
    _inStockOnly = false;
    _suggestions = [];
    loadProducts();
  }

  void applySearchShortcut(String? query) {
    _searchQuery = query;
    _selectedCategoryId = null;
    _minPrice = null;
    _maxPrice = null;
    _sortBy = null;
    _selectedBrands.clear();
    _minRating = null;
    _minDiscount = null;
    _inStockOnly = false;
    _suggestions = [];
    if (query != null && query.trim().length >= 2) {
      _productRepository.saveSearchQuery(query.trim());
      if (!_recentSearches.contains(query.trim())) {
        _recentSearches.insert(0, query.trim());
      }
    }
    loadProducts();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.trim().length < 2) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    _isSuggestionsLoading = true;
    notifyListeners();

    try {
      _suggestions = await _productRepository.getSearchSuggestions(query);
    } catch (e) {
      _suggestions = [];
    } finally {
      _isSuggestionsLoading = false;
      notifyListeners();
    }
  }

  void toggleBrand(String brand) {
    if (_selectedBrands.contains(brand)) {
      _selectedBrands.remove(brand);
    } else {
      _selectedBrands.add(brand);
    }
    loadProducts();
  }

  void setMinRating(double? rating) {
    _minRating = rating;
    loadProducts();
  }

  void setMinDiscount(int? discount) {
    _minDiscount = discount;
    loadProducts();
  }

  void setInStockOnly(bool value) {
    _inStockOnly = value;
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

  void applyAdvancedFilters({
    String? sortBy,
    List<String>? brands,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    int? minDiscount,
    bool? inStockOnly,
  }) {
    _sortBy = sortBy;
    if (brands != null) _selectedBrands = List.from(brands);
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _minRating = minRating;
    _minDiscount = minDiscount;
    if (inStockOnly != null) _inStockOnly = inStockOnly;
    loadProducts();
  }

  void clearFilters() {
    _selectedCategoryId = null;
    _searchQuery = null;
    _minPrice = null;
    _maxPrice = null;
    _sortBy = null;
    _selectedBrands.clear();
    _minRating = null;
    _minDiscount = null;
    _inStockOnly = false;
    loadProducts();
  }
}
