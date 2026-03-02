import '../../../../core/config/api_config.dart';


class TicketAttachmentModel {
  final int id;
  final String fileUrl;
  final String fileType;
  final int size;
  final DateTime uploadedAt;

  const TicketAttachmentModel({
    required this.id,
    required this.fileUrl,
    required this.fileType,
    required this.size,
    required this.uploadedAt,
  });

  factory TicketAttachmentModel.fromJson(Map<String, dynamic> json) {
    final raw = json['uploaded_at']?.toString() ?? '';
    return TicketAttachmentModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      fileUrl: ApiConfig.resolveUrl(json['file']?.toString() ?? ''),
      fileType: json['file_type']?.toString() ?? '',
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
      uploadedAt: DateTime.tryParse(raw) ?? DateTime.now(),
    );
  }
}

