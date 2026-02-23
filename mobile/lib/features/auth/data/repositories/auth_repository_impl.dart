import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Concrete implementation of AuthRepository.
/// Handles the actual HTTP calls and token management.
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  @override
  Future<User> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiConfig.loginUrl,
      body: {'email': email, 'password': password},
      auth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _tokenStorage.saveTokens(
        access: data['access'],
        refresh: data['refresh'],
      );
      // Decode user info from the response or token
      // For now, we store basic user info
      return UserModel.fromJson(
        data['user'] ??
            {'id': 0, 'email': email, 'username': '', 'type': 'CUSTOMER'},
      );
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? error['error'] ?? 'Login failed');
    }
  }

  @override
  Future<User> register(String email, String username, String password) async {
    final response = await _apiClient.post(
      ApiConfig.registerUrl,
      body: {'email': email, 'username': username, 'password': password},
      auth: false,
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Auto-login after registration by saving tokens if returned
      if (data['access'] != null && data['refresh'] != null) {
        await _tokenStorage.saveTokens(
          access: data['access'],
          refresh: data['refresh'],
        );
      }
      return UserModel.fromJson(data['user'] ?? data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['detail'] ?? error['error'] ?? 'Registration failed',
      );
    }
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clearTokens();
  }

  @override
  Future<bool> isLoggedIn() async {
    return await _tokenStorage.hasTokens();
  }

  @override
  Future<User?> getCurrentUser() async {
    // Could be expanded to fetch from /api/user/me/ endpoint
    return null;
  }
}
