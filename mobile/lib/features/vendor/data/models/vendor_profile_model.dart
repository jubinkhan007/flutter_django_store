class VendorProfileModel {
  final int id;
  final String storeName;
  final String description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? policySummary;
  final double avgRating;
  final int reviewCount;
  final DateTime joinedAt;

  VendorProfileModel({
    required this.id,
    required this.storeName,
    required this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.policySummary,
    required this.avgRating,
    required this.reviewCount,
    required this.joinedAt,
  });

  factory VendorProfileModel.fromJson(Map<String, dynamic> json) {
    return VendorProfileModel(
      id: json['id'],
      storeName: json['store_name'] ?? '',
      description: json['description'] ?? '',
      logoUrl: json['logo'],
      coverImageUrl: json['cover_image'],
      policySummary: json['policy_summary'],
      avgRating: double.tryParse(json['avg_rating']?.toString() ?? '0') ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }
}
