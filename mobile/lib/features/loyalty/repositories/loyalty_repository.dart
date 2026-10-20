import 'dart:convert';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/loyalty_account_model.dart';
import '../models/loyalty_transaction_model.dart';

class LoyaltyRepository {
  final ApiClient _apiClient;

  LoyaltyRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<LoyaltyAccountModel> getSummary() async {
    final response = await _apiClient.get(ApiConfig.loyaltySummaryUrl);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return LoyaltyAccountModel.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to load loyalty summary');
    }
  }

  Future<List<LoyaltyTransactionModel>> getTransactions() async {
    final response = await _apiClient.get(ApiConfig.loyaltyTransactionsUrl);
    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      final List<dynamic> list = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List)
              ? decoded['results'] as List<dynamic>
              : [];
      return list
          .map((item) => LoyaltyTransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to load loyalty transactions');
    }
  }

  Future<Map<String, dynamic>> quoteRedemption(int points) async {
    final response = await _apiClient.post(
      ApiConfig.loyaltyQuoteRedemptionUrl,
      body: {'points': points},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to quote points redemption');
    }
  }
}
