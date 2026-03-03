import 'dart:convert';

import '../config/api_config.dart';
import '../network/api_client.dart';
import '../storage/session_storage.dart';

class AnalyticsService {
  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  AnalyticsService({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
  }) : _apiClient = apiClient,
       _sessionStorage = sessionStorage;

  Future<void> logEvent({
    required String eventType,
    required String source,
    int? productId,
    Map<String, dynamic>? metadata,
  }) async {
    await logEvents(
      events: [
        {
          'event_type': eventType,
          'source': source,
          if (productId != null) 'product_id': productId,
          if (metadata != null) 'metadata': metadata,
        },
      ],
    );
  }

  Future<void> logEvents({required List<Map<String, dynamic>> events}) async {
    if (events.isEmpty) return;

    final sessionId = await _sessionStorage.getOrCreateSessionId();
    final enriched = events
        .map(
          (e) => {
            ...e,
            'session_id': sessionId,
          },
        )
        .toList();

    try {
      final resp = await _apiClient.post(
        ApiConfig.analyticsEventsUrl,
        body: {'events': enriched},
        auth: true,
      );

      // Best-effort: ignore failures to avoid breaking UX.
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        // ignore: avoid_print
        print('AnalyticsService.logEvents failed: ${resp.statusCode} ${resp.body}');
      } else {
        assert(() {
          final decoded = jsonDecode(resp.body);
          // ignore: avoid_print
          print('AnalyticsService.logEvents ok: $decoded');
          return true;
        }());
      }
    } catch (e) {
      // ignore: avoid_print
      print('AnalyticsService.logEvents error: $e');
    }
  }
}

