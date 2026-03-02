import 'package:flutter/material.dart';

import '../../data/models/ticket_model.dart';
import '../../data/repositories/support_repository.dart';


class SupportProvider extends ChangeNotifier {
  final SupportRepository _repo;

  SupportProvider({required SupportRepository repository}) : _repo = repository;

  bool _isLoading = false;
  String? _error;
  List<TicketModel> _tickets = [];
  TicketModel? _activeTicket;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<TicketModel> get tickets => _tickets;
  TicketModel? get activeTicket => _activeTicket;

  Future<void> loadTickets({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tickets = await _repo.listTickets(status: status);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openTicket(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _activeTicket = await _repo.getTicketDetail(id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshActive() async {
    final t = _activeTicket;
    if (t == null) return;
    await openTicket(t.id);
  }

  Future<bool> sendMessage(String text) async {
    final t = _activeTicket;
    if (t == null) return false;

    try {
      await _repo.sendMessage(t.id, text: text);
      await openTicket(t.id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMessageWithImages({
    String text = '',
    List<String> imagePaths = const [],
  }) async {
    final t = _activeTicket;
    if (t == null) return false;

    try {
      await _repo.sendMessage(t.id, text: text, imagePaths: imagePaths);
      await openTicket(t.id);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
