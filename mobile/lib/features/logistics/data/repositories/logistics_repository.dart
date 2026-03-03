import 'dart:convert';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/logistics_area_model.dart';
import '../models/logistics_store_model.dart';


class LogisticsRepository {
  final ApiClient _apiClient;

  LogisticsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<LogisticsStoreModel>> listStores({String? courier, String? mode}) async {
    final uri = Uri.parse(ApiConfig.logisticsStoresUrl).replace(
      queryParameters: {
        if (courier != null && courier.trim().isNotEmpty) 'courier': courier.trim(),
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => LogisticsStoreModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load stores');
  }

  Future<List<LogisticsStoreModel>> pathaoStores({String? mode}) async {
    final uri = Uri.parse(ApiConfig.pathaoStoresUrl).replace(
      queryParameters: {
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => LogisticsStoreModel.fromJson(e)).toList();
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to load Pathao stores');
  }

  Future<List<LogisticsAreaModel>> pathaoCities({String? mode}) async {
    final uri = Uri.parse(ApiConfig.pathaoCitiesUrl).replace(
      queryParameters: {
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => LogisticsAreaModel.fromJson(e)).toList();
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to load Pathao cities');
  }

  Future<List<LogisticsAreaModel>> pathaoZones({
    required String cityId,
    String? mode,
  }) async {
    final uri = Uri.parse(ApiConfig.pathaoZonesUrl).replace(
      queryParameters: {
        'city_id': cityId,
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => LogisticsAreaModel.fromJson(e)).toList();
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to load Pathao zones');
  }

  Future<List<LogisticsAreaModel>> pathaoAreas({
    required String zoneId,
    String? mode,
  }) async {
    final uri = Uri.parse(ApiConfig.pathaoAreasUrl).replace(
      queryParameters: {
        'zone_id': zoneId,
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => LogisticsAreaModel.fromJson(e)).toList();
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to load Pathao areas');
  }

  Future<List<LogisticsAreaModel>> searchAreas({
    required String courier,
    required String q,
    String? mode,
  }) async {
    final uri = Uri.parse(ApiConfig.logisticsAreaSearchUrl(courier)).replace(
      queryParameters: {
        'q': q,
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => LogisticsAreaModel.fromJson(e)).toList();
    }
    throw Exception('Failed to search areas');
  }

  Future<void> retryProvision(int subOrderId, {String? mode}) async {
    final resp = await _apiClient.post(
      ApiConfig.logisticsRetryProvisionUrl(subOrderId),
      body: {
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
      },
    );
    if (resp.statusCode == 200) return;
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to retry provision');
  }
}
