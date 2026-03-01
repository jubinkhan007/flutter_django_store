class VendorWalletBalances {
  final double pending;
  final double available;
  final double held;
  final double debt;
  final double total;
  final double lifetimeEarned;
  final double lifetimeWithdrawn;
  final double minWithdrawal;

  const VendorWalletBalances({
    required this.pending,
    required this.available,
    required this.held,
    required this.debt,
    required this.total,
    required this.lifetimeEarned,
    required this.lifetimeWithdrawn,
    required this.minWithdrawal,
  });

  factory VendorWalletBalances.fromJson(Map<String, dynamic> json) {
    return VendorWalletBalances(
      pending: (json['pending'] ?? 0).toDouble(),
      available: (json['available'] ?? 0).toDouble(),
      held: (json['held'] ?? 0).toDouble(),
      debt: (json['debt'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      lifetimeEarned: (json['lifetime_earned'] ?? 0).toDouble(),
      lifetimeWithdrawn: (json['lifetime_withdrawn'] ?? 0).toDouble(),
      minWithdrawal: (json['min_withdrawal'] ?? 10).toDouble(),
    );
  }
}

class VendorLedgerEntry {
  final int id;
  final String entryType;
  final String bucket;
  final String direction;
  final String status;
  final double amount;
  final String referenceType;
  final int referenceId;
  final String description;
  final String createdAt;

  const VendorLedgerEntry({
    required this.id,
    required this.entryType,
    required this.bucket,
    required this.direction,
    required this.status,
    required this.amount,
    required this.referenceType,
    required this.referenceId,
    required this.description,
    required this.createdAt,
  });

  factory VendorLedgerEntry.fromJson(Map<String, dynamic> json) {
    return VendorLedgerEntry(
      id: json['id'] ?? 0,
      entryType: (json['entry_type'] ?? '').toString(),
      bucket: (json['bucket'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      referenceType: (json['reference_type'] ?? '').toString(),
      referenceId: json['reference_id'] ?? 0,
      description: (json['description'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class VendorPayoutMethodModel {
  final int id;
  final String method;
  final String label;
  final Map<String, dynamic> details;
  final bool isVerified;

  const VendorPayoutMethodModel({
    required this.id,
    required this.method,
    required this.label,
    required this.details,
    required this.isVerified,
  });

  factory VendorPayoutMethodModel.fromJson(Map<String, dynamic> json) {
    return VendorPayoutMethodModel(
      id: json['id'] ?? 0,
      method: (json['method'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      isVerified: json['is_verified'] == true,
    );
  }

  String toBankDetailsText() {
    final safeLabel = label.isNotEmpty ? label : method;
    return '$safeLabel: $details';
  }
}

class VendorWalletSummary {
  final VendorWalletBalances balances;
  final List<VendorLedgerEntry> entries;
  final List<VendorPayoutMethodModel> payoutMethods;

  const VendorWalletSummary({
    required this.balances,
    required this.entries,
    required this.payoutMethods,
  });

  factory VendorWalletSummary.fromJson(Map<String, dynamic> json) {
    final balancesJson = (json['balances'] as Map?)?.cast<String, dynamic>() ?? {};
    return VendorWalletSummary(
      balances: VendorWalletBalances.fromJson(balancesJson),
      entries: (json['entries'] as List?)
              ?.map((e) => VendorLedgerEntry.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      payoutMethods: (json['payout_methods'] as List?)
              ?.map((e) => VendorPayoutMethodModel.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }
}

