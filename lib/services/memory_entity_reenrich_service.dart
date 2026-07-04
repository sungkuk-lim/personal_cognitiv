import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory.dart';
import '../services/local_memory_store.dart';
import '../utils/graph_snapshot_store.dart';
import '../utils/memory_graph_semantics.dart';

const String prefGraphReenrichPendingCount = 'graph_reenrich_pending_count';

class MemoryReenrichResult {
  const MemoryReenrichResult({
    required this.memories,
    this.updatedCount = 0,
  });

  final List<Memory> memories;
  final int updatedCount;
}

/// 저장된 entities·요약을 본문 기준으로 다시 맞춥니다 (편집 후 옛 태그 제거).
Future<MemoryReenrichResult> reenrichLocalMemoriesIfNeeded({
  required LocalMemoryStore store,
  required SharedPreferences prefs,
  required List<Memory> memories,
  required String localeCode,
}) async {
  if (memories.isEmpty) return MemoryReenrichResult(memories: memories);

  var updated = 0;
  final out = <Memory>[];
  for (final memory in memories) {
    final enriched = enrichMemoryGraphSemantics(memory, localeCode: localeCode);
    if (_graphSemanticsChanged(memory, enriched)) {
      updated++;
      await removeMemoryGraphFragment(prefs, memory.id);
      out.add(enriched);
    } else {
      out.add(memory);
    }
  }

  if (updated > 0) {
    await store.saveAll(out);
  }
  return MemoryReenrichResult(memories: out, updatedCount: updated);
}

bool _graphSemanticsChanged(Memory before, Memory after) {
  if (before.summary.trim() != after.summary.trim()) return true;
  if (before.entities.length != after.entities.length) return true;
  final a = before.entities.toSet();
  final b = after.entities.toSet();
  if (a.length != b.length) return true;
  for (final tag in a) {
    if (!b.contains(tag)) return true;
  }
  return false;
}

Future<void> writeGraphReenrichPendingNotice(SharedPreferences prefs, int count) async {
  if (count <= 0) return;
  await prefs.setInt(prefGraphReenrichPendingCount, count);
}

int readGraphReenrichPendingCount(SharedPreferences prefs) =>
    prefs.getInt(prefGraphReenrichPendingCount) ?? 0;

Future<void> clearGraphReenrichPendingNotice(SharedPreferences prefs) async {
  await prefs.remove(prefGraphReenrichPendingCount);
}
