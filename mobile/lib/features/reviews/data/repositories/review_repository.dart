import 'dart:convert';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/review_model.dart';
import 'package:http/http.dart' as http;

class ReviewRepository {
  final ApiClient _apiClient;

  ReviewRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<ReviewModel>> getProductReviews(int productId) async {
    final response = await _apiClient.get(
      '${ApiConfig.productsUrl}$productId/reviews/',
      auth: false,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ReviewModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load reviews');
  }

  String _parseError(dynamic error) {
    if (error is Map) {
      return error['detail'] ?? error['non_field_errors']?.first ?? error.toString();
    } else if (error is List && error.isNotEmpty) {
      return error.first.toString();
    }
    return error.toString();
  }

  Future<ReviewModel> submitReview(
    int productId,
    int rating,
    String comment, {
    List<String> imagePaths = const [],
  }) async {
    if (imagePaths.isEmpty) {
      final response = await _apiClient.post(
        '${ApiConfig.productsUrl}$productId/reviews/',
        body: {'rating': rating, 'comment': comment},
      );
      if (response.statusCode == 201) {
        return ReviewModel.fromJson(jsonDecode(response.body));
      }
      throw Exception(_parseError(jsonDecode(response.body)));
    } else {
      // Multipart upload
      final files = <http.MultipartFile>[];
      for (final path in imagePaths) {
        files.add(await http.MultipartFile.fromPath('images', path));
      }

      final response = await _apiClient.postMultipart(
        '${ApiConfig.productsUrl}$productId/reviews/',
        fields: {'rating': rating.toString(), 'comment': comment},
        files: files,
      );

      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 201) {
        return ReviewModel.fromJson(jsonDecode(responseBody));
      }
      throw Exception(_parseError(jsonDecode(responseBody)));
    }
  }

  Future<ReviewReplyModel> replyToReview(int reviewId, String reply) async {
    final response = await _apiClient.post(
      '${ApiConfig.reviewsUrl}$reviewId/reply/',
      body: {'reply': reply},
    );
    if (response.statusCode == 201) {
      return ReviewReplyModel.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body);
    throw Exception(error['error'] ?? 'Failed to post reply');
  }

  Future<ReviewReplyModel> editReply(int reviewId, String reply) async {
    final response = await _apiClient.patch(
      '${ApiConfig.reviewsUrl}$reviewId/reply/',
      body: {'reply': reply},
    );
    if (response.statusCode == 200) {
      return ReviewReplyModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update reply');
  }

  Future<void> voteHelpful(int reviewId) async {
    final response = await _apiClient.post(
      '${ApiConfig.reviewsUrl}$reviewId/vote/',
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to vote');
    }
  }
}
