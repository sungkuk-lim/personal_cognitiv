import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import '../utils/memory_id.dart';

const String prefLocalMemories = 'local_only_memories';

class LocalMemoryStore {
  LocalMemoryStore(this._prefs);
  final SharedPreferences _prefs;

  List<Memory> loadAll() {
    final raw = _prefs.getString(prefLocalMemories);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        if (map['id'] == null || map['id'].toString().isEmpty) {
          map['id'] = generateMemoryId();
        }
        return Memory.fromMap(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<Memory> memories) async {
    final local = memories.where((m) => m.isLocalOnly).toList();
    final encoded = jsonEncode(local.map((m) => m.toLocalJson()).toList());
    await _prefs.setString(prefLocalMemories, encoded);
  }

  Future<Memory> insert(Memory memory) async {
    final saved = memory.copyWith(
      isLocalOnly: true,
      id: ensureMemoryId(memory.id),
    );
    final local = loadAll()..insert(0, saved);
    await saveAll(local);
    return saved;
  }

  Future<bool> delete(String id) async {
    final local = loadAll();
    final before = local.length;
    local.removeWhere((m) => m.id == id);
    if (local.length == before) return false;
    await saveAll(local);
    return true;
  }
}

bool readPrivacyLocalMode(SharedPreferences prefs) => prefs.getBool('privacy_local_mode') ?? false;

Future<void> writePrivacyLocalMode(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool('privacy_local_mode', enabled);
}

List<Memory> searchLocalMemories(List<Memory> memories, String query, {int limit = 5}) {
  final q = query.toLowerCase();
  return memories
      .where((m) {
        if (!m.isLocalOnly) return false;
        if (m.summary.toLowerCase().contains(q)) return true;
        if (m.content.toLowerCase().contains(q)) return true;
        return m.entities.any((e) => e.toLowerCase().contains(q));
      })
      .take(limit)
      .toList();
}
