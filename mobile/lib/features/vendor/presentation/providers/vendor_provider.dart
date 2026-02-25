import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../products/data/models/product_model.dart';
import '../../../orders/data/models/order_model.dart';
import '../../data/models/vendor_customer_model.dart';
import '../../data/models/vendor_coupon_model.dart';
import '../../data/repositories/vendor_repository.dart';

class VendorProvider extends ChangeNotifier {
  final VendorRepository _vendorRepository;

  VendorProvider({required VendorRepository vendorRepository})
    : _vendorRepository = vendorRepository;

  // Stats
  int totalProducts = 0;
  int totalOrders = 0;
  int pendingOrders = 0;
  double totalRevenue = 0;
  double walletBalance = 0;
  double revenue7d = 0;
  double revenue30d = 0;
  int lowStockCount = 0;
  int lateShipmentsCount = 0;
  double cancellationRate30d = 0;
  double fulfillmentRate30d = 0;
  int todayOrders = 0;

  // Products & Orders & Customers
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];
  List<VendorCustomerModel> _customers = [];
  List<VendorCouponModel> _coupons = [];
  List<dynamic> _bulkJobs = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _dashboard;

  List<ProductModel> get products => _products;
  List<OrderModel> get orders => _orders;
  List<VendorCustomerModel> get customers => _customers;
  List<VendorCouponModel> get coupons => _coupons;
  List<dynamic> get bulkJobs => _bulkJobs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get dashboard => _dashboard;

  Future<void> loadStats() async {
    try {
      final stats = await _vendorRepository.getStats();
      totalProducts = stats['total_products'] ?? 0;
      totalOrders = stats['total_orders'] ?? 0;
      pendingOrders = stats['pending_orders'] ?? 0;
      totalRevenue = (stats['total_revenue'] ?? 0).toDouble();
      walletBalance = (stats['wallet_balance'] ?? 0).toDouble();
      
      revenue7d = (stats['revenue_7d'] ?? 0).toDouble();
      revenue30d = (stats['revenue_30d'] ?? 0).toDouble();
      lowStockCount = stats['low_stock_count'] ?? 0;
      lateShipmentsCount = stats['late_shipments_count'] ?? 0;
      cancellationRate30d = (stats['cancellation_rate_30d'] ?? 0).toDouble();
      fulfillmentRate30d = (stats['fulfillment_rate_30d'] ?? 0).toDouble();
      todayOrders = stats['today_orders'] ?? 0;

      notifyListeners();
    } catch (e) {
      // Stats are supplementary, don't block UI
    }
  }

  Future<void> loadDashboard() async {
    try {
      _dashboard = await _vendorRepository.getDashboard();
      notifyListeners();
    } catch (e) {
      // Dashboard info is supplementary
    }
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _vendorRepository.getProducts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct({
    required Map<String, String> fields,
    http.MultipartFile? imageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.addProduct(fields: fields, imageFile: imageFile);
      _isLoading = false;
      notifyListeners();
      await loadProducts();
      await loadStats();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct({
    required int productId,
    required Map<String, String> fields,
    http.MultipartFile? imageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.updateProduct(
        productId: productId,
        fields: fields,
        imageFile: imageFile,
      );
      _isLoading = false;
      notifyListeners();
      await loadProducts();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int productId) async {
    try {
      await _vendorRepository.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
      await loadStats();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _orders = await _vendorRepository.getOrders();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      await _vendorRepository.updateOrderStatus(orderId, newStatus);
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
          status: newStatus,
          paymentStatus: existing.paymentStatus,
          paymentMethod: existing.paymentMethod,
          transactionId: existing.transactionId,
          valId: existing.valId,
          items: existing.items,
          createdAt: existing.createdAt,
          deliveryAddress: existing.deliveryAddress,
        );
      }
      notifyListeners();
      await loadStats();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.cancelOrder(orderId);
      await loadOrders();
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

  Future<bool> onboard(String storeName, String description) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.onboard(storeName, description);
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

  Future<void> loadCustomers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _customers = await _vendorRepository.loadCustomers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCoupons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _coupons = await _vendorRepository.getCoupons();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCoupon({
    required String code,
    required String discountType,
    required double discountValue,
    double? minOrderAmount,
    List<int> productIds = const [],
    List<int> categoryIds = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final coupon = await _vendorRepository.createCoupon(
        code: code,
        discountType: discountType,
        discountValue: discountValue,
        minOrderAmount: minOrderAmount,
        productIds: productIds,
        categoryIds: categoryIds,
      );
      _coupons = [coupon, ..._coupons];
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

  Future<bool> uploadBulkJob(String jobType, String filePath) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.uploadBulkJob(jobType, filePath);
      await loadBulkJobs();
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

  Future<void> loadBulkJobs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bulkJobs = await _vendorRepository.getBulkJobs();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }
}
