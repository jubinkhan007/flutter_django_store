import 'package:shared_preferences/shared_preferences.dart';

/// Handles persisting and retrieving JWT tokens and user info.
/// Single Responsibility: Only manages local storage.
class TokenStorage {
  static const _accessKey = 'jwt_access_token';
  static const _refreshKey = 'jwt_refresh_token';
  static const _userTypeKey = 'user_type';
  static const _userEmailKey = 'user_email';

  Future<SharedPreferences> _prefs({bool reload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) {
      await prefs.reload();
    }
    return prefs;
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final prefs = await _prefs();
    final okAccess = await prefs.setString(_accessKey, access);
    final okRefresh = await prefs.setString(_refreshKey, refresh);

    assert(() {
      final accessPreview = access.length >= 12 ? access.substring(0, 12) : access;
      final refreshPreview =
          refresh.length >= 12 ? refresh.substring(0, 12) : refresh;
      // Intentionally only log a short prefix (never full tokens).
      // ignore: avoid_print
      print(
        'TokenStorage.saveTokens(access=${access.length} chars, prefix=$accessPreview..., ok=$okAccess; '
        'refresh=${refresh.length} chars, prefix=$refreshPreview..., ok=$okRefresh)',
      );
      return true;
    }());

    if (!okAccess || !okRefresh) {
      throw Exception('Failed to persist auth tokens');
    }
  }

  Future<void> saveUserInfo({
    required String type,
    required String email,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(_userTypeKey, type);
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs(reload: true);
    return prefs.getString(_accessKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _prefs(reload: true);
    return prefs.getString(_refreshKey);
  }

  Future<String?> getUserType() async {
    final prefs = await _prefs(reload: true);
    return prefs.getString(_userTypeKey);
  }

  Future<String?> getUserEmail() async {
    final prefs = await _prefs(reload: true);
    return prefs.getString(_userEmailKey);
  }

  Future<void> clearTokens() async {
    final prefs = await _prefs();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userTypeKey);
    await prefs.remove(_userEmailKey);
  }

  Future<bool> hasTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    final has =
        (access != null && access.isNotEmpty) ||
        (refresh != null && refresh.isNotEmpty);

    assert(() {
      // ignore: avoid_print
      print(
        'TokenStorage.hasTokens(access=${access?.length ?? 0} chars, refresh=${refresh?.length ?? 0} chars) => $has',
      );
      return true;
    }());

    return has;
  }
}
