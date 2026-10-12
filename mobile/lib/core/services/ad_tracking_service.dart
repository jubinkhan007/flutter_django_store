import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';

class AdTrackingService {
  static final AdTrackingService _instance = AdTrackingService._internal();
  factory AdTrackingService() => _instance;
  AdTrackingService._internal();

  final ApiClient _apiClient = ApiClient();
  final String _sessionId = const Uuid().v4();
  final Set<int> _recordedImpressions = <int>{};

  String get sessionId => _sessionId;

  /// Records an impression for a sponsored campaign.
  /// Deduplicates within the current session to avoid duplicate calls on widget rebuilds.
  Future<void> recordImpression(int campaignId, {String source = 'SEARCH'}) async {
    if (_recordedImpressions.contains(campaignId)) return;
    _recordedImpressions.add(campaignId);

    try {
      final response = await _apiClient.post(
        ApiConfig.adImpressionsUrl,
        body: {
          'campaign_id': campaignId,
          'session_id': _sessionId,
          'source': source,
        },
        auth: true,
      );
      if (kDebugMode) {
        debugPrint(
            'Ad impression tracked for campaign $campaignId: status ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to track ad impression: $e');
      }
    }
  }

  /// Records a click for a sponsored campaign with a unique click_id for idempotency.
  Future<void> recordClick(int campaignId) async {
    final clickId = const Uuid().v4();
    try {
      final response = await _apiClient.post(
        ApiConfig.adClicksUrl,
        body: {
          'campaign_id': campaignId,
          'session_id': _sessionId,
          'click_id': clickId,
        },
        auth: true,
      );
      if (kDebugMode) {
        debugPrint(
            'Ad click tracked for campaign $campaignId (clickId: $clickId): status ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to track ad click: $e');
      }
    }
  }
}
