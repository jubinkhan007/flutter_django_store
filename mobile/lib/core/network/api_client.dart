import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

/// Centralized HTTP client that automatically injects JWT tokens.
/// Dependency Inversion: All features depend on this abstraction, not raw http.
class ApiClient {
  final TokenStorage _tokenStorage;
  final http.Client _httpClient;

  ApiClient({TokenStorage? tokenStorage, http.Client? httpClient})
    : _tokenStorage = tokenStorage ?? TokenStorage(),
      _httpClient = httpClient ?? http.Client();

  /// Builds headers with optional JWT authentication.
  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// GET request
  Future<http.Response> get(String url, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return _httpClient.get(Uri.parse(url), headers: headers);
  }

  /// POST request
  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = await _headers(auth: auth);
    return _httpClient.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// PUT request
  Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = await _headers(auth: auth);
    return _httpClient.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// PATCH request
  Future<http.Response> patch(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = await _headers(auth: auth);
    return _httpClient.patch(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// DELETE request
  Future<http.Response> delete(String url, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return _httpClient.delete(Uri.parse(url), headers: headers);
  }
}
