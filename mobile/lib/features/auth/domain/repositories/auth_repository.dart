import '../entities/user.dart';

/// Abstract repository — Dependency Inversion Principle.
/// Domain layer defines the contract, data layer provides the implementation.
abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<User> register(String email, String username, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<User?> getCurrentUser();
}
