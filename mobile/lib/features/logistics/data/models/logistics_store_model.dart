class LogisticsStoreModel {
  final int id;
  final String courier;
  final String mode;
  final String name;
  final String externalStoreId;

  const LogisticsStoreModel({
    required this.id,
    required this.courier,
    required this.mode,
    required this.name,
    required this.externalStoreId,
  });

  factory LogisticsStoreModel.fromJson(Map<String, dynamic> json) {
    return LogisticsStoreModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      courier: json['courier']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      externalStoreId: json['external_store_id']?.toString() ?? '',
    );
  }
}

