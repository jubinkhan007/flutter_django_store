import '../../../../core/config/api_config.dart';

class AdProductSummary {
  final int id;
  final String name;
  final double price;
  final int stockQuantity;
  final bool inStock;
  final String? image;
  final bool isAvailable;

  const AdProductSummary({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    required this.inStock,
    this.image,
    required this.isAvailable,
  });

  factory AdProductSummary.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image']?.toString();
    final resolvedImage = (rawImage == null || rawImage.trim().isEmpty)
        ? null
        : ApiConfig.resolveUrl(rawImage);

    return AdProductSummary(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      stockQuantity: json['stock_quantity'] ?? 0,
      inStock: json['in_stock'] ?? true,
      image: resolvedImage,
      isAvailable: json['is_available'] ?? true,
    );
  }
}

class AdCampaignModel {
  final int id;
  final int vendor;
  final int product;
  final AdProductSummary? productDetail;
  final double budgetTotal;
  final double budgetSpent;
  final double? dailyBudget;
  final double costPerClick;
  final String status;
  final String? startsAt;
  final String? endsAt;
  final List<String> keywords;
  final int impressionsCount;
  final int clicksCount;
  final double ctr;
  final String createdAt;
  final String? updatedAt;

  const AdCampaignModel({
    required this.id,
    required this.vendor,
    required this.product,
    this.productDetail,
    required this.budgetTotal,
    required this.budgetSpent,
    this.dailyBudget,
    required this.costPerClick,
    required this.status,
    this.startsAt,
    this.endsAt,
    required this.keywords,
    required this.impressionsCount,
    required this.clicksCount,
    required this.ctr,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isPaused => status == 'PAUSED';
  bool get isExhausted => status == 'EXHAUSTED';

  double get budgetProgress =>
      budgetTotal > 0 ? (budgetSpent / budgetTotal).clamp(0.0, 1.0) : 0.0;

  factory AdCampaignModel.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    List<String> parsedKeywords = [];
    if (rawKeywords is List) {
      parsedKeywords = rawKeywords.map((e) => e.toString()).toList();
    }

    return AdCampaignModel(
      id: json['id'] ?? 0,
      vendor: json['vendor'] ?? 0,
      product: json['product'] ?? 0,
      productDetail: json['product_detail'] != null
          ? AdProductSummary.fromJson(json['product_detail'])
          : null,
      budgetTotal:
          double.tryParse(json['budget_total']?.toString() ?? '0') ?? 0.0,
      budgetSpent:
          double.tryParse(json['budget_spent']?.toString() ?? '0') ?? 0.0,
      dailyBudget: json['daily_budget'] != null
          ? double.tryParse(json['daily_budget'].toString())
          : null,
      costPerClick:
          double.tryParse(json['cost_per_click']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'DRAFT',
      startsAt: json['starts_at'],
      endsAt: json['ends_at'],
      keywords: parsedKeywords,
      impressionsCount: json['impressions_count'] ?? 0,
      clicksCount: json['clicks_count'] ?? 0,
      ctr: double.tryParse(json['ctr']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
    );
  }
}

class AdStatsModel {
  final int totalCampaigns;
  final int activeCampaigns;
  final int totalImpressions;
  final int totalClicks;
  final double totalSpend;
  final double avgCtr;
  final double adBalance;
  final double availableBalance;

  const AdStatsModel({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.totalImpressions,
    required this.totalClicks,
    required this.totalSpend,
    required this.avgCtr,
    required this.adBalance,
    required this.availableBalance,
  });

  factory AdStatsModel.fromJson(Map<String, dynamic> json) {
    return AdStatsModel(
      totalCampaigns: json['total_campaigns'] ?? 0,
      activeCampaigns: json['active_campaigns'] ?? 0,
      totalImpressions: json['total_impressions'] ?? 0,
      totalClicks: json['total_clicks'] ?? 0,
      totalSpend:
          double.tryParse(json['total_spend']?.toString() ?? '0') ?? 0.0,
      avgCtr: double.tryParse(json['avg_ctr']?.toString() ?? '0') ?? 0.0,
      adBalance:
          double.tryParse(json['ad_balance']?.toString() ?? '0') ?? 0.0,
      availableBalance:
          double.tryParse(json['available_balance']?.toString() ?? '0') ?? 0.0,
    );
  }

  factory AdStatsModel.empty() {
    return const AdStatsModel(
      totalCampaigns: 0,
      activeCampaigns: 0,
      totalImpressions: 0,
      totalClicks: 0,
      totalSpend: 0.0,
      avgCtr: 0.0,
      adBalance: 0.0,
      availableBalance: 0.0,
    );
  }
}
