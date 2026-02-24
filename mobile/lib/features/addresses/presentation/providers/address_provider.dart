import 'package:flutter/foundation.dart';
import '../../data/models/address_model.dart';
import '../../data/repositories/address_repository.dart';

class AddressProvider with ChangeNotifier {
  final AddressRepository _addressRepository;

  List<AddressModel> _addresses = [];
  bool _isLoading = false;
  String? _error;

  AddressProvider({required AddressRepository addressRepository})
    : _addressRepository = addressRepository;

  List<AddressModel> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AddressModel? get defaultAddress {
    try {
      return _addresses.firstWhere((addr) => addr.isDefault);
    } catch (e) {
      if (_addresses.isNotEmpty) return _addresses.first;
      return null;
    }
  }

  Future<void> loadAddresses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _addresses = await _addressRepository.getAddresses();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAddress(AddressModel address) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newAddress = await _addressRepository.createAddress(address);
      _addresses.insert(0, newAddress);

      // If we added a default address, update others locally
      if (newAddress.isDefault) {
        _updateLocalDefaults(newAddress.id);
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

  Future<bool> updateAddress(AddressModel address) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedAddress = await _addressRepository.updateAddress(address);
      final index = _addresses.indexWhere((a) => a.id == updatedAddress.id);
      if (index != -1) {
        _addresses[index] = updatedAddress;
      }

      if (updatedAddress.isDefault) {
        _updateLocalDefaults(updatedAddress.id);
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

  Future<bool> deleteAddress(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _addressRepository.deleteAddress(id);
      _addresses.removeWhere((a) => a.id == id);

      // If we deleted the default and there are still addresses, make the first one default locally
      // The backend handles this too, but we update our local sync to be safe
      if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
        final first = _addresses.first;
        _addresses[0] = first.copyWith(isDefault: true);
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

  void _updateLocalDefaults(int newDefaultId) {
    for (int i = 0; i < _addresses.length; i++) {
      if (_addresses[i].id != newDefaultId && _addresses[i].isDefault) {
        _addresses[i] = _addresses[i].copyWith(isDefault: false);
      }
    }
  }
}
