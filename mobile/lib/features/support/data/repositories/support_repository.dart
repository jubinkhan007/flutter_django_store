import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/ticket_model.dart';


class SupportRepository {
  final ApiClient _apiClient;

  SupportRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<TicketModel>> listTickets({String? status}) async {
    final uri = Uri.parse(ApiConfig.supportTicketsUrl).replace(
      queryParameters: (status == null || status.trim().isEmpty)
          ? null
          : {'status': status.trim()},
    );
    final resp = await _apiClient.get(uri.toString());
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      return data.map((e) => TicketModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load tickets');
  }

  Future<TicketModel> getTicketDetail(int id) async {
    final resp = await _apiClient.get(ApiConfig.supportTicketDetailUrl(id));
    if (resp.statusCode == 200) {
      return TicketModel.fromJson(jsonDecode(resp.body));
    }
    throw Exception('Failed to load ticket');
  }

  Future<TicketModel> createTicket({
    String category = 'OTHER',
    String subject = '',
    int? orderId,
    int? subOrderId,
    int? returnRequestId,
    required String message,
    List<String> imagePaths = const [],
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Message is required');
    }

    if (imagePaths.isEmpty) {
      final resp = await _apiClient.post(
        ApiConfig.supportTicketsUrl,
        body: {
          'category': category,
          'subject': subject,
          if (orderId != null) 'order_id': orderId,
          if (subOrderId != null) 'sub_order_id': subOrderId,
          if (returnRequestId != null) 'return_request_id': returnRequestId,
          'message': trimmedMessage,
        },
      );
      if (resp.statusCode == 201) {
        return TicketModel.fromJson(jsonDecode(resp.body));
      }
      final err = jsonDecode(resp.body);
      throw Exception(err['error'] ?? 'Failed to create ticket');
    }

    final files = <http.MultipartFile>[];
    for (final path in imagePaths) {
      files.add(await http.MultipartFile.fromPath('images', path));
    }

    final resp = await _apiClient.postMultipart(
      ApiConfig.supportTicketsUrl,
      fields: {
        'category': category,
        'subject': subject,
        if (orderId != null) 'order_id': orderId.toString(),
        if (subOrderId != null) 'sub_order_id': subOrderId.toString(),
        if (returnRequestId != null)
          'return_request_id': returnRequestId.toString(),
        'message': trimmedMessage,
      },
      files: files,
    );
    final body = await resp.stream.bytesToString();
    if (resp.statusCode == 201) {
      return TicketModel.fromJson(jsonDecode(body));
    }
    final err = jsonDecode(body);
    throw Exception(err['error'] ?? 'Failed to create ticket');
  }

  Future<void> sendMessage(
    int ticketId, {
    String text = '',
    List<String> imagePaths = const [],
    bool isInternalNote = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imagePaths.isEmpty) {
      throw Exception('Message or image is required');
    }

    if (imagePaths.isEmpty) {
      final resp = await _apiClient.post(
        ApiConfig.supportTicketMessagesUrl(ticketId),
        body: {
          'kind': 'TEXT',
          'text': trimmed,
          'is_internal_note': isInternalNote,
        },
      );
      if (resp.statusCode != 201) {
        final err = jsonDecode(resp.body);
        throw Exception(err['error'] ?? 'Failed to send message');
      }
      return;
    }

    final files = <http.MultipartFile>[];
    for (final path in imagePaths) {
      files.add(await http.MultipartFile.fromPath('images', path));
    }

    final resp = await _apiClient.postMultipart(
      ApiConfig.supportTicketMessagesUrl(ticketId),
      fields: {
        'kind': trimmed.isEmpty ? 'IMAGE' : 'TEXT',
        'text': trimmed,
        'is_internal_note': isInternalNote.toString(),
      },
      files: files,
    );
    final body = await resp.stream.bytesToString();
    if (resp.statusCode != 201) {
      final err = jsonDecode(body);
      throw Exception(err['error'] ?? 'Failed to send message');
    }
  }

  Future<TicketModel> closeTicket(int ticketId) async {
    final resp = await _apiClient.post(ApiConfig.supportTicketCloseUrl(ticketId));
    if (resp.statusCode == 200) {
      return TicketModel.fromJson(jsonDecode(resp.body));
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to close ticket');
  }

  Future<TicketModel> reopenTicket(int ticketId) async {
    final resp =
        await _apiClient.post(ApiConfig.supportTicketReopenUrl(ticketId));
    if (resp.statusCode == 200) {
      return TicketModel.fromJson(jsonDecode(resp.body));
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to reopen ticket');
  }

  Future<TicketModel> assignTicket(int ticketId, {required int assignedToId}) async {
    final resp = await _apiClient.post(
      ApiConfig.supportTicketAssignUrl(ticketId),
      body: {'assigned_to_id': assignedToId},
    );
    if (resp.statusCode == 200) {
      return TicketModel.fromJson(jsonDecode(resp.body));
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to assign ticket');
  }

  Future<TicketModel> setTicketStatus(int ticketId, {required String status}) async {
    final resp = await _apiClient.post(
      ApiConfig.supportTicketStatusUrl(ticketId),
      body: {'status': status},
    );
    if (resp.statusCode == 200) {
      return TicketModel.fromJson(jsonDecode(resp.body));
    }
    final err = jsonDecode(resp.body);
    throw Exception(err['error'] ?? 'Failed to update status');
  }
}
