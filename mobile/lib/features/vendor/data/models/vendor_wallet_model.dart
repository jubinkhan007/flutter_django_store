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
  final String? verifiedAt;
  final String? verificationNotes;

  const VendorPayoutMethodModel({
    required this.id,
    required this.method,
    required this.label,
    required this.details,
    required this.isVerified,
    this.verifiedAt,
    this.verificationNotes,
  });

  factory VendorPayoutMethodModel.fromJson(Map<String, dynamic> json) {
    return VendorPayoutMethodModel(
      id: json['id'] ?? 0,
      method: (json['method'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
      isVerified: json['is_verified'] == true,
      verifiedAt: json['verified_at']?.toString(),
      verificationNotes: json['verification_notes']?.toString(),
    );
  }

  String toBankDetailsText() {
    final safeLabel = label.isNotEmpty ? label : method;
    return '$safeLabel: $details';
  }
}

class VendorPayoutRequestModel {
  final int id;
  final double amount;
  final String status;
  final int? payoutMethodId;
  final String disbursalChannel;
  final String bankDetails;
  final String? gatewayReference;
  final double gatewayFee;
  final String failureReason;
  final bool isAutomated;
  final String adminNote;
  final String requestedAt;
  final String? processedAt;

  const VendorPayoutRequestModel({
    required this.id,
    required this.amount,
    required this.status,
    this.payoutMethodId,
    required this.disbursalChannel,
    required this.bankDetails,
    this.gatewayReference,
    required this.gatewayFee,
    required this.failureReason,
    required this.isAutomated,
    required this.adminNote,
    required this.requestedAt,
    this.processedAt,
  });

  factory VendorPayoutRequestModel.fromJson(Map<String, dynamic> json) {
    return VendorPayoutRequestModel(
      id: json['id'] ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: (json['status'] ?? 'REQUESTED').toString(),
      payoutMethodId: json['payout_method'] is int ? json['payout_method'] : null,
      disbursalChannel: (json['disbursal_channel'] ?? '').toString(),
      bankDetails: (json['bank_details'] ?? '').toString(),
      gatewayReference: json['gateway_reference']?.toString(),
      gatewayFee: double.tryParse(json['gateway_fee']?.toString() ?? '0') ?? 0.0,
      failureReason: (json['failure_reason'] ?? '').toString(),
      isAutomated: json['is_automated'] == true,
      adminNote: (json['admin_note'] ?? '').toString(),
      requestedAt: (json['requested_at'] ?? '').toString(),
      processedAt: json['processed_at']?.toString(),
    );
  }
}

class VendorAutoPayoutSettings {
  final bool isEnabled;
  final String schedule; // WEEKLY, BIWEEKLY, MONTHLY
  final double threshold;
  final int? preferredMethodId;
  final String? lastPayoutAt;

  const VendorAutoPayoutSettings({
    required this.isEnabled,
    required this.schedule,
    required this.threshold,
    this.preferredMethodId,
    this.lastPayoutAt,
  });

  factory VendorAutoPayoutSettings.fromJson(Map<String, dynamic> json) {
    return VendorAutoPayoutSettings(
      isEnabled: json['is_enabled'] == true || json['is_auto_payout_enabled'] == true,
      schedule: (json['schedule'] ?? json['auto_payout_schedule'] ?? 'WEEKLY').toString(),
      threshold: double.tryParse((json['threshold'] ?? json['auto_payout_threshold'] ?? 1000).toString()) ?? 1000.0,
      preferredMethodId: json['preferred_method_id'] is int
          ? json['preferred_method_id']
          : (json['preferred_payout_method'] is int ? json['preferred_payout_method'] : null),
      lastPayoutAt: json['last_payout_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_auto_payout_enabled': isEnabled,
      'auto_payout_schedule': schedule,
      'auto_payout_threshold': threshold.toStringAsFixed(2),
      if (preferredMethodId != null) 'preferred_payout_method': preferredMethodId,
    };
  }
}

class VendorWalletSummary {
  final VendorWalletBalances balances;
  final VendorAutoPayoutSettings? autoPayout;
  final List<VendorLedgerEntry> entries;
  final List<VendorPayoutMethodModel> payoutMethods;
  final List<VendorPayoutRequestModel> payoutRequests;

  const VendorWalletSummary({
    required this.balances,
    this.autoPayout,
    required this.entries,
    required this.payoutMethods,
    required this.payoutRequests,
  });

  factory VendorWalletSummary.fromJson(Map<String, dynamic> json) {
    final balancesJson = (json['balances'] as Map?)?.cast<String, dynamic>() ?? {};
    final autoPayoutJson = (json['auto_payout'] as Map?)?.cast<String, dynamic>();

    return VendorWalletSummary(
      balances: VendorWalletBalances.fromJson(balancesJson),
      autoPayout: autoPayoutJson != null ? VendorAutoPayoutSettings.fromJson(autoPayoutJson) : null,
      entries: (json['entries'] as List?)
              ?.map((e) => VendorLedgerEntry.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      payoutMethods: (json['payout_methods'] as List?)
              ?.map((e) => VendorPayoutMethodModel.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      payoutRequests: (json['payout_requests'] as List?)
              ?.map((e) => VendorPayoutRequestModel.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }
}
