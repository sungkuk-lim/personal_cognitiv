import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../models/memory.dart';

/// 썸네일 경로를 기억 ID·타입에 맞게 정리합니다.
/// (빈 ID 시대에 모든 기억이 같은 `/.jpg` 를 공유하던 문제 복구)
Map<String, String> reconcileMemoryImagePaths(
  List<Memory> memories,
  Map<String, String> paths,
) {
  final cleaned = Map<String, String>.from(paths);
  final orphanPath = cleaned.remove('');

  final imageMemories = memories.where((m) => m.type == 'image').toList();
  final imageIds = imageMemories.map((m) => m.id).toSet();

  // 음성·텍스트 기억에는 썸네일을 붙이지 않음
  cleaned.removeWhere((id, _) => !imageIds.contains(id));

  // 고아 경로(빈 ID 키) → 아직 썸네일 없는 사진 기억 1건에만 연결
  if (orphanPath != null && File(orphanPath).existsSync()) {
    final withoutThumb = imageMemories.where((m) => !cleaned.containsKey(m.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (withoutThumb.isNotEmpty) {
      cleaned[withoutThumb.first.id] = orphanPath;
    }
  }

  // 동일 파일 경로가 여러 ID에 매핑된 경우 → 가장 오래된 사진 기억 1건만 유지
  final byPath = <String, List<String>>{};
  for (final entry in cleaned.entries) {
    byPath.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  for (final ids in byPath.values) {
    if (ids.length <= 1) continue;
    final candidates = imageMemories.where((m) => ids.contains(m.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final keepId = candidates.isNotEmpty ? candidates.first.id : ids.first;
    for (final id in ids) {
      if (id != keepId) cleaned.remove(id);
    }
  }

  return cleaned;
}

Future<Map<String, String>> loadReconciledImagePaths(
  SharedPreferences prefs,
  List<Memory> memories,
) async {
  final raw = readMemoryImagePaths(prefs);
  final reconciled = reconcileMemoryImagePaths(memories, raw);
  if (reconciled.length != raw.length || !_mapsEqual(reconciled, raw)) {
    await saveMemoryImagePaths(prefs, reconciled);
  }
  return reconciled;
}

bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

String? imagePathForMemory(Memory memory, Map<String, String> paths) {
  if (memory.type != 'image') return null;
  final path = paths[memory.id];
  if (path == null || path.isEmpty) return null;
  if (!File(path).existsSync()) return null;
  return path;
}
