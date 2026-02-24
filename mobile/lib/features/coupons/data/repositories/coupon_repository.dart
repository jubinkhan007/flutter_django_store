import 'dart:convert';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/available_coupon_model.dart';
import '../models/coupon_model.dart';

class CouponRepository {
  final ApiClient _apiClient;

  CouponRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<CouponModel>> listGlobalCoupons() async {
    final resp = await _apiClient.get(ApiConfig.couponsUrl);
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => CouponModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load coupons');
  }

  Future<CouponModel> validateCoupon(
    String code,
    List<Map<String, dynamic>> items,
  ) async {
    final resp = await _apiClient.post(
      ApiConfig.couponValidateUrl,
      body: {'code': code, 'items': items},
    );
    if (resp.statusCode == 200) {
      return CouponModel.fromJson(jsonDecode(resp.body));
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Invalid coupon');
  }

  Future<List<AvailableCouponModel>> availableCoupons({
    required List<Map<String, dynamic>> items,
  }) async {
    final resp = await _apiClient.post(
      ApiConfig.couponAvailableUrl,
      body: {'items': items},
    );
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => AvailableCouponModel.fromJson(e)).toList();
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to load available coupons');
  }
}
