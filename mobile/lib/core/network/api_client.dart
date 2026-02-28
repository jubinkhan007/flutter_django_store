import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../storage/token_storage.dart';

/// Centralized HTTP client that automatically injects JWT tokens
/// and handles automatic token refreshing on 401 Unauthorized.
class ApiClient {
  final TokenStorage _tokenStorage;
  final http.Client _httpClient;

  /// Callback fired when a refresh fails (meaning the session is truly over).
  /// This should be wired up to log the user out globally.
  VoidCallback? onUnauthenticated;

  ApiClient({
    TokenStorage? tokenStorage,
    http.Client? httpClient,
    this.onUnauthenticated,
  }) : _tokenStorage = tokenStorage ?? TokenStorage(),
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

  /// Attempts to refresh the access token. Returns true if successful.
  Future<bool> _refreshToken() async {
    final refresh = await _tokenStorage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return false;
    }

    try {
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.tokenRefreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access'] as String?;
        // Some backends return a new refresh token as well, others don't.
        final newRefresh = data['refresh'] as String? ?? refresh;

        if (newAccess != null) {
          await _tokenStorage.saveTokens(
            access: newAccess,
            refresh: newRefresh,
          );
          return true;
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('ApiClient._refreshToken error: $e');
        return true;
      }());
    }
    return false;
  }

  /// Wraps standard HTTP requests with automatic 401 retry logic.
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() requestFn, {
    required bool auth,
  }) async {
    // 1. Initial attempt
    var response = await requestFn();

    // 2. If unauthorized, and we used auth, try to refresh and retry
    if (response.statusCode == 401 && auth) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // 3. Retry the request now that tokens are updated
        response = await requestFn();
      } else {
        // 4. Refresh failed, flush tokens and notify the app
        await _tokenStorage.clearTokens();
        onUnauthenticated?.call();
      }
    }
    return response;
  }

  /// Wraps multipart HTTP requests with automatic 401 retry logic.
  Future<http.StreamedResponse> _multipartRequestWithRetry(
    Future<http.StreamedResponse> Function() requestFn, {
    required bool auth,
  }) async {
    var response = await requestFn();

    if (response.statusCode == 401 && auth) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // We must re-create the request entirely because Streams/Files
        // in multipart requests get consumed/drained on the first attempt.
        response = await requestFn();
      } else {
        await _tokenStorage.clearTokens();
        onUnauthenticated?.call();
      }
    }
    return response;
  }

  /// GET request
  Future<http.Response> get(String url, {bool auth = true}) async {
    return _requestWithRetry(() async {
      final headers = await _headers(auth: auth);
      return _httpClient.get(Uri.parse(url), headers: headers);
    }, auth: auth);
  }

  /// POST request
  Future<http.Response> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    bool auth = true,
  }) async {
    return _requestWithRetry(() async {
      final headers = await _headers(auth: auth);
      if (extraHeaders != null) headers.addAll(extraHeaders);
      return _httpClient.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }, auth: auth);
  }

  /// PUT request
  Future<http.Response> put(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _requestWithRetry(() async {
      final headers = await _headers(auth: auth);
      return _httpClient.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }, auth: auth);
  }

  /// PATCH request
  Future<http.Response> patch(
    String url, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _requestWithRetry(() async {
      final headers = await _headers(auth: auth);
      return _httpClient.patch(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }, auth: auth);
  }

  /// DELETE request
  Future<http.Response> delete(String url, {bool auth = true}) async {
    return _requestWithRetry(() async {
      final headers = await _headers(auth: auth);
      return _httpClient.delete(Uri.parse(url), headers: headers);
    }, auth: auth);
  }

  /// POST Multipart request (for image uploads)
  Future<http.StreamedResponse> postMultipart(
    String url, {
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
    bool auth = true,
  }) async {
    // Read files into memory once so we can clone them if a retry is needed.
    final fileBytesList = <List<int>>[];
    if (files != null) {
      for (final file in files) {
        fileBytesList.add(await file.finalize().toBytes());
      }
    }

    return _multipartRequestWithRetry(() async {
      final headers = await _headers(auth: auth);
      headers.remove('Content-Type');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      request.fields.addAll(fields);

      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final bytes = fileBytesList[i];
          final fileClone = http.MultipartFile.fromBytes(
            file.field,
            bytes,
            filename: file.filename,
            contentType: file.contentType,
          );
          request.files.add(fileClone);
        }
      }

      return await request.send();
    }, auth: auth);
  }

  /// PUT Multipart request (for updating products with images)
  Future<http.StreamedResponse> putMultipart(
    String url, {
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
    bool auth = true,
  }) async {
    // Read files into memory once so we can clone them if a retry is needed.
    final fileBytesList = <List<int>>[];
    if (files != null) {
      for (final file in files) {
        fileBytesList.add(await file.finalize().toBytes());
      }
    }

    return _multipartRequestWithRetry(() async {
      final headers = await _headers(auth: auth);
      headers.remove('Content-Type');

      final request = http.MultipartRequest('PUT', Uri.parse(url));
      request.headers.addAll(headers);
      request.fields.addAll(fields);

      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final bytes = fileBytesList[i];
          final fileClone = http.MultipartFile.fromBytes(
            file.field,
            bytes,
            filename: file.filename,
            contentType: file.contentType,
          );
          request.files.add(fileClone);
        }
      }

      return await request.send();
    }, auth: auth);
  }
}
