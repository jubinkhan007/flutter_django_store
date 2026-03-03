import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionStorage {
  static const _key = 'session_id_v1';
  final Uuid _uuid = const Uuid();

  Future<String> getOrCreateSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final id = _uuid.v4();
    await prefs.setString(_key, id);
    return id;
  }
}

