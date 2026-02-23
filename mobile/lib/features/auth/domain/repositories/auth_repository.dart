import '../entities/user.dart';

/// Abstract repository — Dependency Inversion Principle.
/// Domain layer defines the contract, data layer provides the implementation.
abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<User> register(String email, String username, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<User?> getCurrentUser();

  /// Restores minimal user info from local storage (for routing/UI).
  /// Note: This does not validate token expiry or hit the backend.
  Future<User?> getSavedUser();

  /// Persists user info used for role-based routing.
  Future<void> saveUserInfo({required String type, required String email});
}
