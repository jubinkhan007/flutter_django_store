import 'package:flutter/foundation.dart';
import '../../data/models/delivery_estimate_model.dart';
import '../../data/repositories/delivery_estimate_repository.dart';

class DeliveryEstimateProvider extends ChangeNotifier {
  final DeliveryEstimateRepository _repository;

  DeliveryEstimateProvider({required DeliveryEstimateRepository repository})
      : _repository = repository;

  DeliveryEstimateModel? _estimate;
  bool _isLoading = false;
  String? _errorMessage;
  int? _activeProductId;
  String? _currentCity;
  String? _currentArea;

  DeliveryEstimateModel? get estimate => _estimate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentCity => _currentCity;
  String? get currentArea => _currentArea;

  Future<void> loadEstimate(
    int productId, {
    String? city,
    String? area,
    int? variantId,
    int? quantity,
    bool force = false,
  }) async {
    if (!force &&
        _activeProductId == productId &&
        _estimate != null &&
        city == null &&
        area == null) {
      return;
    }

    _activeProductId = productId;
    if (city != null) _currentCity = city;
    if (area != null) _currentArea = area;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _estimate = await _repository.getEstimate(
        productId: productId,
        city: _currentCity,
        area: _currentArea,
        variantId: variantId,
        quantity: quantity,
      );
      if (_estimate != null) {
        _currentCity = _estimate!.destinationCity;
        _currentArea = _estimate!.destinationArea;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateLocation(int productId, {required String city, String? area, int? variantId}) {
    _currentCity = city;
    _currentArea = area ?? '';
    loadEstimate(productId, city: _currentCity, area: _currentArea, variantId: variantId, force: true);
  }

  void reset() {
    _estimate = null;
    _isLoading = false;
    _errorMessage = null;
    _activeProductId = null;
    _currentCity = null;
    _currentArea = null;
  }
}
