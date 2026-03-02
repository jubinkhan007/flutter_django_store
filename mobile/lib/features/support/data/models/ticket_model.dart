import 'ticket_message_model.dart';


class TicketModel {
  final int id;
  final String ticketNumber;
  final String subject;
  final String category;
  final String status;
  final DateTime lastActivityAt;
  final DateTime createdAt;
  final int? orderId;
  final int? subOrderId;
  final int? returnRequestId;
  final int? vendorId;
  final int? assignedToId;
  final bool isOverdueFirstResponse;
  final bool isOverdueResolution;
  final Map<String, dynamic> contextSnapshot;
  final List<TicketMessageModel> messages;

  TicketModel({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.category,
    required this.status,
    required this.lastActivityAt,
    required this.createdAt,
    required this.orderId,
    required this.subOrderId,
    required this.returnRequestId,
    required this.vendorId,
    required this.assignedToId,
    required this.isOverdueFirstResponse,
    required this.isOverdueResolution,
    required this.contextSnapshot,
    required this.messages,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDT(String key) {
      final raw = json[key]?.toString();
      return DateTime.tryParse(raw ?? '') ?? DateTime.now();
    }

    final msgs = (json['messages'] as List?) ?? const [];
    return TicketModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      ticketNumber: json['ticket_number']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      status: json['status']?.toString() ?? 'OPEN',
      lastActivityAt: parseDT('last_activity_at'),
      createdAt: parseDT('created_at'),
      orderId: json['order_id'] == null
          ? null
          : int.tryParse(json['order_id'].toString()),
      subOrderId: json['sub_order_id'] == null
          ? null
          : int.tryParse(json['sub_order_id'].toString()),
      returnRequestId: json['return_request_id'] == null
          ? null
          : int.tryParse(json['return_request_id'].toString()),
      vendorId: json['vendor_id'] == null
          ? null
          : int.tryParse(json['vendor_id'].toString()),
      assignedToId: json['assigned_to_id'] == null
          ? null
          : int.tryParse(json['assigned_to_id'].toString()),
      isOverdueFirstResponse: json['is_overdue_first_response'] == true,
      isOverdueResolution: json['is_overdue_resolution'] == true,
      contextSnapshot: (json['context_snapshot'] is Map<String, dynamic>)
          ? (json['context_snapshot'] as Map<String, dynamic>)
          : <String, dynamic>{},
      messages: msgs
          .whereType<Map>()
          .map((e) => TicketMessageModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
