import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import 'graph_layout.dart';
import '../../utils/memory_entity_extract.dart';

/// 노드 시트·도움말용 한 줄 요약.
String graphNodeLocalInsightLine({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
  required String localeCode,
}) {
  if (memories.isEmpty) {
    return localeCode == 'ko' ? '연결된 기억 없음' : 'No linked memories';
  }

  final isKo = localeCode == 'ko';
  final count = memories.length;
  final recent = memories
      .where((m) => m.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
      .length;

  if (node.kind == GraphNodeKind.person || node.kind == GraphNodeKind.place) {
    final places = <String, int>{};
    for (final memory in memories.take(12)) {
      final fragment = fragments[memory.id];
      if (fragment != null) {
        for (final s in fragment.satellites) {
          if (s.kind == 'place') places[s.label] = (places[s.label] ?? 0) + 1;
        }
      }
      for (final p in extractMemoryEntities(memory).places) {
        places[p] = (places[p] ?? 0) + 1;
      }
    }
    if (places.isNotEmpty) {
      final top = places.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return isKo
          ? '${node.title} · $count건 · ${top.first.key} $recent건(30일)'
          : '${node.title} · $count · ${top.first.key} · $recent (30d)';
    }
  }

  return isKo ? '${node.title} · $count건 · 30일 $recent건' : '${node.title} · $count · $recent (30d)';
}
