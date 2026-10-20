import 'loyalty_transaction_model.dart';

class NextTierInfo {
  final String currentTier;
  final String? nextTier;
  final int targetPoints;
  final int pointsNeeded;
  final double progressRatio;

  const NextTierInfo({
    required this.currentTier,
    this.nextTier,
    required this.targetPoints,
    required this.pointsNeeded,
    required this.progressRatio,
  });

  factory NextTierInfo.fromJson(Map<String, dynamic> json) {
    return NextTierInfo(
      currentTier: json['current_tier']?.toString() ?? 'BRONZE',
      nextTier: json['next_tier']?.toString(),
      targetPoints: json['target_points'] as int? ?? 500,
      pointsNeeded: json['points_needed'] as int? ?? 0,
      progressRatio:
          double.tryParse(json['progress_ratio']?.toString() ?? '') ?? 0.0,
    );
  }
}

class LoyaltyAccountModel {
  final int pointsBalance;
  final int lifetimePointsEarned;
  final int lifetimePointsRedeemed;
  final String tier;
  final double tierMultiplier;
  final double pointsValueBdt;
  final NextTierInfo nextTierInfo;
  final List<LoyaltyTransactionModel> recentTransactions;
  final DateTime updatedAt;

  const LoyaltyAccountModel({
    required this.pointsBalance,
    required this.lifetimePointsEarned,
    required this.lifetimePointsRedeemed,
    required this.tier,
    required this.tierMultiplier,
    required this.pointsValueBdt,
    required this.nextTierInfo,
    required this.recentTransactions,
    required this.updatedAt,
  });

  bool get isPlatinum => tier.toUpperCase() == 'PLATINUM';
  bool get isGold => tier.toUpperCase() == 'GOLD';
  bool get isSilver => tier.toUpperCase() == 'SILVER';
  bool get isBronze => tier.toUpperCase() == 'BRONZE';

  factory LoyaltyAccountModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyAccountModel(
      pointsBalance: json['points_balance'] as int? ?? 0,
      lifetimePointsEarned: json['lifetime_points_earned'] as int? ?? 0,
      lifetimePointsRedeemed: json['lifetime_points_redeemed'] as int? ?? 0,
      tier: json['tier']?.toString() ?? 'BRONZE',
      tierMultiplier:
          double.tryParse(json['tier_multiplier']?.toString() ?? '') ?? 1.0,
      pointsValueBdt:
          double.tryParse(json['points_value_bdt']?.toString() ?? '') ?? 0.0,
      nextTierInfo: json['next_tier_info'] != null
          ? NextTierInfo.fromJson(json['next_tier_info'] as Map<String, dynamic>)
          : const NextTierInfo(
              currentTier: 'BRONZE',
              targetPoints: 500,
              pointsNeeded: 500,
              progressRatio: 0.0,
            ),
      recentTransactions: (json['recent_transactions'] as List?)
              ?.map(
                (item) => LoyaltyTransactionModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
