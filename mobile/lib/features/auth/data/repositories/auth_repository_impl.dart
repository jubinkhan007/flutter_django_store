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

  Map<String, dynamic>? _tryDecodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final normalized = base64Url.normalize(parts[1]);
      final payloadBytes = base64Url.decode(normalized);
      final payloadString = utf8.decode(payloadBytes);
      final payload = jsonDecode(payloadString);
      return payload is Map<String, dynamic> ? payload : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<User> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiConfig.loginUrl,
      body: {'email': email, 'password': password},
      auth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;

      if (access == null || refresh == null) {
        throw Exception('Login failed: missing tokens');
      }

      await _tokenStorage.saveTokens(
        access: access,
        refresh: refresh,
      );

      final payload = _tryDecodeJwtPayload(access);
      final user = UserModel.fromJson(
        data['user'] ??
            {
              'id': payload?['user_id'] ?? payload?['id'] ?? 0,
              'email': payload?['email'] ?? email,
              'username': payload?['username'] ?? '',
              'type': payload?['type'] ?? 'CUSTOMER',
            },
      );
      // Persist user type for role-based routing
      await _tokenStorage.saveUserInfo(type: user.type, email: user.email);
      return user;
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
      // Auto-login after registration.
      // Backend usually returns the created user only (no tokens), so we fall back to logging in.
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;

      if (access != null && refresh != null) {
        await _tokenStorage.saveTokens(access: access, refresh: refresh);
        final user = UserModel.fromJson(data['user'] ?? data);
        await _tokenStorage.saveUserInfo(type: user.type, email: user.email);
        return user;
      }

      return login(email, password);
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
    return _tokenStorage.hasTokens();
  }

  @override
  Future<User?> getCurrentUser() async {
    // Could be expanded to fetch from /api/user/me/ endpoint
    return null;
  }

  @override
  Future<User?> getSavedUser() async {
    final hasToken = await _tokenStorage.hasTokens();
    if (!hasToken) return null;

    // Stored values are always saved on login/vendor-onboarding — prefer them.
    final storedEmail = await _tokenStorage.getUserEmail();
    final storedType = await _tokenStorage.getUserType();

    final access = await _tokenStorage.getAccessToken();
    if (access != null && access.isNotEmpty) {
      final payload = _tryDecodeJwtPayload(access);
      if (payload != null) {
        // Safely cast user_id — JWT may encode it as num/double on some runtimes.
        final rawId = payload['user_id'] ?? payload['id'];
        final id = rawId is int ? rawId : (rawId as num?)?.toInt() ?? 0;
        return User(
          id: id,
          email: payload['email'] ?? storedEmail ?? '',
          username: payload['username'] ?? '',
          // Prefer stored type (updated on vendor onboarding) over JWT claim.
          type: (storedType != null && storedType.isNotEmpty)
              ? storedType
              : (payload['type'] ?? 'CUSTOMER'),
        );
      }
    }

    return User(
      id: 0,
      email: storedEmail ?? '',
      username: '',
      type: (storedType == null || storedType.isEmpty) ? 'CUSTOMER' : storedType,
    );
  }

  @override
  Future<void> saveUserInfo({required String type, required String email}) async {
    await _tokenStorage.saveUserInfo(type: type, email: email);
  }
}
