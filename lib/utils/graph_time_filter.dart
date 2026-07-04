import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';

/// 관계망 기본 표시 구간 — 전체 기억은 타임라인·회상에서 연속성 유지.
enum GraphTimeRange {
  days7,
  days30,
  days90,
  all,
}

extension GraphTimeRangeX on GraphTimeRange {
  int? get dayCount => switch (this) {
        GraphTimeRange.days7 => 7,
        GraphTimeRange.days30 => 30,
        GraphTimeRange.days90 => 90,
        GraphTimeRange.all => null,
      };

  String get prefValue => name;

  static GraphTimeRange fromPref(String? raw) {
    return GraphTimeRange.values.firstWhere(
      (r) => r.name == raw,
      orElse: () => GraphTimeRange.days7,
    );
  }
}

List<Memory> filterMemoriesForGraphRange(List<Memory> memories, GraphTimeRange range) {
  final days = range.dayCount;
  if (days == null || memories.isEmpty) return memories;
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final primary = memories.where((m) => !isGraphNoteMemory(m) && !m.createdAt.isBefore(cutoff)).toList();
  final primaryIds = primary.map((m) => m.id).toSet();
  final allPrimary = memories.where((m) => !isGraphNoteMemory(m)).toList();
  final notes = memories.where((m) {
    if (!isGraphNoteMemory(m)) return false;
    if (!m.createdAt.isBefore(cutoff)) return true;
    final relatedId = graphNoteRelatedMemoryId(m);
    if (relatedId != null && primaryIds.contains(relatedId)) return true;
    final related = resolveGraphNoteRelatedMemory(m, allPrimary);
    return related != null && primaryIds.contains(related.id);
  });
  return [...primary, ...notes];
}
