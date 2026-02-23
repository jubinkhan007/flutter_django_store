import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Auth state management using ChangeNotifier (Provider pattern).
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthProvider({required AuthRepository authRepository})
    : _authRepository = authRepository;

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  Future<void> restoreSession() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final loggedIn = await _authRepository.isLoggedIn();
      if (!loggedIn) {
        _user = null;
      } else {
        _user = await _authRepository.getSavedUser();
      }
    } catch (_) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authRepository.login(email, password);
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

  Future<bool> register(String email, String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authRepository.register(email, username, password);
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

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final loggedIn = await _authRepository.isLoggedIn();
    if (!loggedIn) {
      _user = null;
      notifyListeners();
    }
  }

  /// Update the user's type locally (e.g., after vendor onboarding)
  Future<void> updateUserType(String newType) async {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        email: _user!.email,
        username: _user!.username,
        type: newType,
      );
      await _authRepository.saveUserInfo(type: newType, email: _user!.email);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
