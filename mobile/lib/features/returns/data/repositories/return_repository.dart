import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/return_request_model.dart';


class ReturnRepository {
  final ApiClient _apiClient;

  ReturnRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<ReturnRequestModel>> listMyReturns() async {
    final resp = await _apiClient.get(ApiConfig.returnsUrl);
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => ReturnRequestModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load returns');
  }

  Future<List<ReturnRequestModel>> createReturn({
    required int orderId,
    required String requestType,
    required String reason,
    required String fulfillment,
    required String refundMethodPreference,
    required List<Map<String, dynamic>> items,
    String reasonDetails = '',
    String customerNote = '',
  }) async {
    final resp = await _apiClient.post(
      ApiConfig.returnsUrl,
      body: {
        'order_id': orderId,
        'request_type': requestType,
        'reason': reason,
        'reason_details': reasonDetails,
        'customer_note': customerNote,
        'fulfillment': fulfillment,
        'refund_method_preference': refundMethodPreference,
        'items': items,
      },
    );

    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final returns = (data['returns'] as List?) ?? const [];
      return returns.map((e) => ReturnRequestModel.fromJson(e)).toList();
    }

    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to create return');
  }

  Future<ReturnRequestModel> uploadReturnImages({
    required int returnId,
    required List<String> imagePaths,
  }) async {
    ReturnRequestModel? last;
    for (final path in imagePaths) {
      final file = await http.MultipartFile.fromPath('images', path);
      final resp = await _apiClient.postMultipart(
        '${ApiConfig.returnsUrl}$returnId/images/',
        fields: const {},
        files: [file],
      );
      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 201) {
        last = ReturnRequestModel.fromJson(jsonDecode(body));
      } else {
        final error = jsonDecode(body);
        throw Exception(error['error'] ?? 'Failed to upload images');
      }
    }
    if (last == null) throw Exception('No images uploaded');
    return last;
  }

  Future<List<ReturnRequestModel>> listVendorReturns() async {
    final resp = await _apiClient.get(ApiConfig.vendorReturnsUrl);
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => ReturnRequestModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load vendor returns');
  }

  Future<ReturnRequestModel> vendorApprove(int returnId, {String note = ''}) async {
    // Backward-compatible wrapper; prefer the overload with scheduling/instructions.
    return vendorApproveWithDetails(returnId, note: note);
  }

  Future<ReturnRequestModel> vendorApproveWithDetails(
    int returnId, {
    String note = '',
    DateTime? pickupWindowStart,
    DateTime? pickupWindowEnd,
    String dropoffInstructions = '',
  }) async {
    final resp = await _apiClient.post(
      '${ApiConfig.vendorReturnsUrl}$returnId/approve/',
      body: {
        'note': note,
        if (pickupWindowStart != null) 'pickup_window_start': pickupWindowStart.toIso8601String(),
        if (pickupWindowEnd != null) 'pickup_window_end': pickupWindowEnd.toIso8601String(),
        if (dropoffInstructions.isNotEmpty) 'dropoff_instructions': dropoffInstructions,
      },
    );
    if (resp.statusCode == 200) {
      return ReturnRequestModel.fromJson(jsonDecode(resp.body));
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to approve');
  }

  Future<ReturnRequestModel> vendorReject(int returnId, {String note = ''}) async {
    final resp = await _apiClient.post(
      '${ApiConfig.vendorReturnsUrl}$returnId/reject/',
      body: {'note': note},
    );
    if (resp.statusCode == 200) {
      return ReturnRequestModel.fromJson(jsonDecode(resp.body));
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to reject');
  }

  Future<ReturnRequestModel> vendorMarkReceived(int returnId) async {
    final resp = await _apiClient.post(
      '${ApiConfig.vendorReturnsUrl}$returnId/received/',
    );
    if (resp.statusCode == 200) {
      return ReturnRequestModel.fromJson(jsonDecode(resp.body));
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to mark received');
  }

  Future<ReturnRequestModel> vendorRefundToWallet(int returnId) async {
    return vendorInitiateRefund(returnId, method: 'WALLET');
  }

  Future<ReturnRequestModel> vendorInitiateRefund(
    int returnId, {
    required String method,
    double? amount,
  }) async {
    final resp = await _apiClient.post(
      '${ApiConfig.vendorReturnsUrl}$returnId/refund/',
      body: {
        'method': method,
        if (amount != null) 'amount': amount,
      },
    );
    if (resp.statusCode == 200 || resp.statusCode == 202) {
      return ReturnRequestModel.fromJson(jsonDecode(resp.body));
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to refund');
  }

  Future<ReturnRequestModel> vendorCompleteOriginalRefund(
    int returnId, {
    String reference = '',
  }) async {
    final resp = await _apiClient.post(
      '${ApiConfig.vendorReturnsUrl}$returnId/refund/complete/',
      body: {'reference': reference},
    );
    if (resp.statusCode == 200) {
      return ReturnRequestModel.fromJson(jsonDecode(resp.body));
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['error'] ?? 'Failed to complete refund');
  }
}
