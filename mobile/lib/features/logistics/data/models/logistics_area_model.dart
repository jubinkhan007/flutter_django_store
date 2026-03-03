class LogisticsAreaModel {
  final int id;
  final String courier;
  final String mode;
  final String kind;
  final String externalId;
  final String name;
  final String? parentExternalId;

  const LogisticsAreaModel({
    required this.id,
    required this.courier,
    required this.mode,
    required this.kind,
    required this.externalId,
    required this.name,
    required this.parentExternalId,
  });

  factory LogisticsAreaModel.fromJson(Map<String, dynamic> json) {
    return LogisticsAreaModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      courier: json['courier']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      externalId: json['external_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentExternalId: json['parent_external_id']?.toString(),
    );
  }
}

