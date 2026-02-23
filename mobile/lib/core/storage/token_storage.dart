import 'package:shared_preferences/shared_preferences.dart';

/// Handles persisting and retrieving JWT tokens using SharedPreferences.
/// Single Responsibility: Only manages token storage.
class TokenStorage {
  static const _accessKey = 'jwt_access_token';
  static const _refreshKey = 'jwt_refresh_token';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
