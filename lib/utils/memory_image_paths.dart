import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';

String? _cachedMemoryImagesDir;

/// 관계망·타임라인에서 동기 경로 조회를 위해 이미지 폴더를 미리 캐시합니다.
Future<void> warmMemoryImagesDirectoryCache() async {
  if (_cachedMemoryImagesDir != null) return;
  final dir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory('${dir.path}/memory_images');
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }
  _cachedMemoryImagesDir = imagesDir.path;
}

void setMemoryImagesDirectoryCacheForTest(String path) {
  _cachedMemoryImagesDir = path;
}

void resetMemoryImagesDirectoryCacheForTest() {
  _cachedMemoryImagesDir = null;
}

List<String> diskImagePathsForMemoryId(String memoryId) {
  final dir = _cachedMemoryImagesDir;
  if (dir == null || memoryId.isEmpty) return const [];

  final paths = <String>[];
  for (var i = 0; i < 64; i++) {
    final indexed = File('$dir/${memoryId}_$i.jpg');
    if (!indexed.existsSync()) {
      if (i > 0) break;
      continue;
    }
    paths.add(indexed.path);
  }
  if (paths.isNotEmpty) return paths;

  final legacy = File('$dir/$memoryId.jpg');
  if (legacy.existsSync()) return [legacy.path];
  return [];
}

/// prefs에 저장된 경로가 있으면 그것만 사용 — 디스크 이중 병합으로 중복 표시 방지.
List<String> resolvedImagePathsForMemoryId(String memoryId, Map<String, List<String>> paths) {
  final prefsList = paths[memoryId];
  if (prefsList != null && prefsList.isNotEmpty) {
    return prefsList.where((p) => p.isNotEmpty && File(p).existsSync()).toList();
  }

  final merged = <String>[];
  final seen = <String>{};
  for (final path in diskImagePathsForMemoryId(memoryId)) {
    if (seen.add(path)) merged.add(path);
  }
  return merged;
}

String? fullImagePathAtIndex(String memoryId, int index) {
  final dir = _cachedMemoryImagesDir;
  if (dir == null) return null;
  final full = File('$dir/${memoryId}_${index}_full.jpg');
  if (full.existsSync()) return full.path;
  final thumb = File('$dir/${memoryId}_$index.jpg');
  return thumb.existsSync() ? thumb.path : null;
}

List<String> resolvedFullImagePathsForMemoryId(String memoryId, Map<String, List<String>> paths) {
  final thumbs = resolvedImagePathsForMemoryId(memoryId, paths);
  if (thumbs.isEmpty) return const [];
  final fullPaths = <String>[];
  for (var i = 0; i < thumbs.length; i++) {
    fullPaths.add(fullImagePathAtIndex(memoryId, i) ?? thumbs[i]);
  }
  return fullPaths;
}

String? primaryImagePathForMemoryId(String memoryId, Map<String, List<String>> paths) {
  final list = resolvedImagePathsForMemoryId(memoryId, paths);
  return list.isEmpty ? null : list.first;
}

int imageCountForMemoryId(String memoryId, Map<String, List<String>> paths) {
  return resolvedImagePathsForMemoryId(memoryId, paths).length;
}

/// 썸네일 경로를 기억 ID·타입에 맞게 정리합니다. (기억당 여러 장 지원)
Map<String, List<String>> reconcileMemoryImagePaths(
  List<Memory> memories,
  Map<String, List<String>> paths,
) {
  final cleaned = <String, List<String>>{};
  for (final entry in paths.entries) {
    final existing = entry.value.where((p) => p.isNotEmpty && File(p).existsSync()).toList();
    if (existing.isNotEmpty) {
      cleaned[entry.key] = existing;
    }
  }

  final orphanList = cleaned.remove('');
  final imageMemories = memories.where((m) => m.type == 'image').toList();
  final imageIds = imageMemories.map((m) => m.id).toSet();

  cleaned.removeWhere((id, _) => !imageIds.contains(id));

  if (orphanList != null && orphanList.isNotEmpty) {
    final withoutThumb = imageMemories.where((m) => !cleaned.containsKey(m.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (withoutThumb.isNotEmpty) {
      cleaned[withoutThumb.first.id] = List<String>.from(orphanList);
    }
  }

  return cleaned;
}

/// 디스크에만 있는 썸네일을 prefs 맵에 병합합니다.
Map<String, List<String>> mergeDiskImagePaths(Map<String, List<String>> paths, List<Memory> memories) {
  final merged = Map<String, List<String>>.from(paths);
  for (final memory in memories.where((m) => m.type == 'image' || graphNoteAnchorNodeId(m) != null)) {
    if ((merged[memory.id] ?? const []).isNotEmpty) continue;
    final disk = diskImagePathsForMemoryId(memory.id);
    if (disk.isEmpty) continue;
    final existing = merged[memory.id] ?? const [];
    final combined = <String>[];
    final seen = <String>{};
    for (final path in [...existing, ...disk]) {
      if (seen.add(path) && File(path).existsSync()) combined.add(path);
    }
    if (combined.isNotEmpty) merged[memory.id] = combined;
  }
  return merged;
}

Future<Map<String, List<String>>> loadReconciledImagePaths(
  SharedPreferences prefs,
  List<Memory> memories,
) async {
  await warmMemoryImagesDirectoryCache();
  final raw = readMemoryImagePaths(prefs);
  final reconciled = mergeDiskImagePaths(reconcileMemoryImagePaths(memories, raw), memories);
  if (!_mapsEqual(reconciled, raw)) {
    await saveMemoryImagePaths(prefs, reconciled);
  }
  return reconciled;
}

bool _mapsEqual(Map<String, List<String>> a, Map<String, List<String>> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || other.length != entry.value.length) return false;
    for (var i = 0; i < entry.value.length; i++) {
      if (other[i] != entry.value[i]) return false;
    }
  }
  return true;
}

List<String> imagePathsForMemory(Memory memory, Map<String, List<String>> paths) {
  if (memory.type != 'image') return const [];
  return resolvedImagePathsForMemoryId(memory.id, paths);
}

String? primaryImagePathForMemory(Memory memory, Map<String, List<String>> paths) {
  if (memory.type != 'image') return null;
  return primaryImagePathForMemoryId(memory.id, paths);
}

/// 하위 호환: 첫 번째 썸네일 경로.
String? imagePathForMemory(Memory memory, Map<String, List<String>> paths) {
  return primaryImagePathForMemory(memory, paths);
}

int imageCountForMemory(Memory memory, Map<String, List<String>> paths) {
  if (memory.type != 'image') return 0;
  return imageCountForMemoryId(memory.id, paths);
}
