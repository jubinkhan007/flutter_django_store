import 'package:flutter/material.dart';
import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _repository;

  ReviewProvider({required ReviewRepository repository})
      : _repository = repository;

  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _error;

  List<ReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get averageRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(0, (acc, r) => acc + r.rating);
    return sum / _reviews.length;
  }

  Map<int, int> get ratingDistribution {
    final dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in _reviews) {
      dist[r.rating] = (dist[r.rating] ?? 0) + 1;
    }
    return dist;
  }

  Future<void> loadReviews(int productId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reviews = await _repository.getProductReviews(productId);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitReview(
    int productId,
    int rating,
    String comment,
  ) async {
    _error = null;
    try {
      final review = await _repository.submitReview(productId, rating, comment);
      _reviews.insert(0, review);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> replyToReview(int reviewId, String reply) async {
    _error = null;
    try {
      final replyModel = await _repository.replyToReview(reviewId, reply);
      _updateReviewReply(reviewId, replyModel);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> editReply(int reviewId, String reply) async {
    _error = null;
    try {
      final replyModel = await _repository.editReply(reviewId, reply);
      _updateReviewReply(reviewId, replyModel);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void _updateReviewReply(int reviewId, ReviewReplyModel replyModel) {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index >= 0) {
      _reviews[index] = _reviews[index].copyWith(reply: replyModel);
      notifyListeners();
    }
  }

  void clear() {
    _reviews = [];
    _error = null;
    _isLoading = false;
  }
}
