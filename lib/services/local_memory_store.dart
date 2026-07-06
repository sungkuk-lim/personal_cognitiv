import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/prefs.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../utils/memory_id.dart';
import '../utils/memory_keyword_ui.dart';
import '../utils/ocr_utils.dart';

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

  Future<void> clearAll() async {
    await _prefs.remove(prefLocalMemories);
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

  Future<Memory?> update(Memory memory) async {
    final local = loadAll();
    final index = local.indexWhere((m) => m.id == memory.id);
    if (index < 0) return null;
    local[index] = memory.copyWith(isLocalOnly: true);
    await saveAll(local);
    return local[index];
  }
}

bool readPrivacyLocalMode(SharedPreferences prefs) => prefs.getBool('privacy_local_mode') ?? false;

/// 게스트·프라이버시 모드 여부 (Provider와 prefs 모두 확인).
bool isLocalOnlyMode(
  SharedPreferences prefs, {
  bool privacyMode = false,
  bool guestMode = false,
}) =>
    privacyMode ||
    guestMode ||
    readPrivacyLocalMode(prefs) ||
    readGuestMode(prefs);

Future<void> writePrivacyLocalMode(SharedPreferences prefs, bool enabled) async {
  await prefs.setBool('privacy_local_mode', enabled);
}

bool isPhotoSearchQuery(String query) {
  const keys = {'사진', 'photo', 'photos', 'image', 'images', 'picture', '촬영', '앨범', 'gallery'};
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  return keys.any((k) => q == k || q.contains(k));
}

List<Memory> searchLocalMemories(
  List<Memory> memories,
  String query, {
  int limit = 8,
  bool requireLocalOnly = true,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];

  if (isPhotoSearchQuery(q)) {
    final photos = memories
        .where((m) => isUserFacingMemory(m) && (!requireLocalOnly || m.isLocalOnly) && m.type == 'image')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return photos.take(limit).toList();
  }

  final scored = <({Memory memory, int score})>[];
  for (final memory in memories) {
    if (!isUserFacingMemory(memory)) continue;
    if (requireLocalOnly && !memory.isLocalOnly) continue;
    if (memory.type == 'image' && q == 'image') {
      scored.add((memory: memory, score: 30));
      continue;
    }
    final score = memoryKeywordMatchScore(memory, q);
    if (score > 0) {
      scored.add((memory: memory, score: score));
      continue;
    }
    if (memory.userMemo.toLowerCase().contains(q)) {
      scored.add((memory: memory, score: 25));
    }
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return b.memory.createdAt.compareTo(a.memory.createdAt);
  });
  return scored.take(limit).map((e) => e.memory).toList();
}

String searchResultTitle(Memory memory) => graphTitleForMemory(memory);
