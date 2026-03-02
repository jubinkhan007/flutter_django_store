import 'ticket_attachment_model.dart';

class TicketMessageModel {
  final int id;
  final int? senderId;
  final String kind;
  final String text;
  final List<TicketAttachmentModel> attachments;
  final DateTime createdAt;

  TicketMessageModel({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.text,
    required this.attachments,
    required this.createdAt,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString() ?? '';
    final atts = (json['attachments'] as List?) ?? const [];
    return TicketMessageModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      senderId: json['sender_id'] == null
          ? null
          : int.tryParse(json['sender_id'].toString()),
      kind: json['kind']?.toString() ?? 'TEXT',
      text: json['text']?.toString() ?? '',
      attachments: atts
          .whereType<Map>()
          .map((e) => TicketAttachmentModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      createdAt: DateTime.tryParse(created) ?? DateTime.now(),
    );
  }
}
