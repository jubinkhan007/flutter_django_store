class ReviewReplyModel {
  final int id;
  final String vendorName;
  final String reply;
  final String createdAt;

  const ReviewReplyModel({
    required this.id,
    required this.vendorName,
    required this.reply,
    required this.createdAt,
  });

  factory ReviewReplyModel.fromJson(Map<String, dynamic> json) {
    return ReviewReplyModel(
      id: json['id'] ?? 0,
      vendorName: json['vendor_name'] ?? '',
      reply: json['reply'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ReviewModel {
  final int id;
  final int customerId;
  final String customerUsername;
  final int rating;
  final String comment;
  final ReviewReplyModel? reply;
  final List<ReviewImageModel> images;
  final bool isVerifiedPurchase;
  final int helpfulVotes;
  final String createdAt;

  const ReviewModel({
    required this.id,
    required this.customerId,
    required this.customerUsername,
    required this.rating,
    required this.comment,
    this.reply,
    this.images = const [],
    this.isVerifiedPurchase = false,
    this.helpfulVotes = 0,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? 0,
      customerId: json['customer'] ?? 0,
      customerUsername: json['customer_username'] ?? 'Customer',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      reply: json['reply'] != null
          ? ReviewReplyModel.fromJson(json['reply'])
          : null,
      images:
          (json['images'] as List?)
              ?.map((i) => ReviewImageModel.fromJson(i))
              .toList() ??
          [],
      isVerifiedPurchase: json['is_verified_purchase'] ?? false,
      helpfulVotes: json['helpful_votes'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  ReviewModel copyWith({
    ReviewReplyModel? reply,
    List<ReviewImageModel>? images,
    int? helpfulVotes,
  }) {
    return ReviewModel(
      id: id,
      customerId: customerId,
      customerUsername: customerUsername,
      rating: rating,
      comment: comment,
      reply: reply ?? this.reply,
      images: images ?? this.images,
      isVerifiedPurchase: isVerifiedPurchase,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      createdAt: createdAt,
    );
  }
}

class ReviewImageModel {
  final int id;
  final String imageUrl;

  const ReviewImageModel({required this.id, required this.imageUrl});

  factory ReviewImageModel.fromJson(Map<String, dynamic> json) {
    return ReviewImageModel(id: json['id'] ?? 0, imageUrl: json['image'] ?? '');
  }
}
