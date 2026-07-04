import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import '../utils/memory_entity_extract.dart';
import '../utils/memory_keyword_ui.dart';

/// AI 없이 관계망·기록에서 패턴을 뽑아 재미(리텐션)용 통찰을 만듭니다.
class GraphInsight {
  const GraphInsight({required this.message, this.entity, this.kind = GraphInsightKind.growth});

  final String message;
  final String? entity;
  final GraphInsightKind kind;
}

enum GraphInsightKind { growth, person, place, milestone }

List<GraphInsight> generateGraphInsights({
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
  required String localeCode,
  int limit = 3,
}) {
  if (memories.isEmpty) return const [];

  final isKo = localeCode == 'ko';
  final now = DateTime.now();
  final last30 = memories.where((m) => m.createdAt.isAfter(now.subtract(const Duration(days: 30)))).toList();
  final prev30 = memories.where((m) {
    final t = m.createdAt;
    final start = now.subtract(const Duration(days: 60));
    final end = now.subtract(const Duration(days: 30));
    return t.isAfter(start) && t.isBefore(end);
  }).toList();

  final insights = <GraphInsight>[];

  final topPerson = _topPerson(memories, fragments);
  if (topPerson != null) {
    insights.add(GraphInsight(
      message: isKo
          ? '핵심 · ${topPerson.key} ${topPerson.value}건'
          : 'Top · ${topPerson.key} ${topPerson.value}',
      entity: topPerson.key,
      kind: GraphInsightKind.person,
    ));
  }

  final growth = _topicGrowth(last30, prev30, 'Flutter', isKo);
  if (growth != null) insights.add(growth);

  final repeatedPlace = _repeatedPlace(memories, fragments, isKo);
  if (repeatedPlace != null) insights.add(repeatedPlace);

  final nodeCount = estimateGraphNodeCount(memories, fragments);
  for (final milestone in _milestones(nodeCount, isKo)) {
    insights.add(milestone);
  }

  return insights.take(limit).toList();
}

int estimateGraphNodeCount(List<Memory> memories, Map<String, GraphMemoryFragment> fragments) {
  final nodes = <String>{};
  for (final memory in memories) {
    nodes.add('memory_${memory.id}');
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        nodes.add('${s.kind}_${s.label}');
      }
    }
    for (final e in userVisibleEntityLabels(memory)) {
      nodes.add('entity_$e');
    }
  }
  return nodes.length;
}

MapEntry<String, int>? _topPerson(List<Memory> memories, Map<String, GraphMemoryFragment> fragments) {
  final counts = <String, int>{};
  for (final memory in memories) {
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        if (s.kind == 'person') counts[s.label] = (counts[s.label] ?? 0) + 1;
      }
    }
    for (final p in extractMemoryEntities(memory).people) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
}

GraphInsight? _topicGrowth(List<Memory> recent, List<Memory> previous, String keyword, bool isKo) {
  int countIn(List<Memory> list) =>
      list.where((m) => memoryMatchesKeyword(m, keyword)).length;

  final recentCount = countIn(recent);
  final prevCount = countIn(previous);
  if (recentCount < 3) return null;
  if (recentCount <= prevCount) return null;

  final delta = recentCount - prevCount;
  return GraphInsight(
    message: isKo
        ? '성장 · $keyword +$delta (30일 $recentCount건)'
        : 'Growth · $keyword +$delta ($recentCount in 30d)',
    entity: keyword,
    kind: GraphInsightKind.growth,
  );
}

GraphInsight? _repeatedPlace(List<Memory> memories, Map<String, GraphMemoryFragment> fragments, bool isKo) {
  final counts = <String, int>{};
  for (final memory in memories) {
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        if (s.kind == 'place') counts[s.label] = (counts[s.label] ?? 0) + 1;
      }
    }
    for (final p in extractMemoryEntities(memory).places) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
  }
  final repeated = counts.entries.where((e) => e.value >= 3).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (repeated.isEmpty) return null;
  final top = repeated.first;
  return GraphInsight(
    message: isKo ? '장소 · ${top.key} ${top.value}회' : 'Place · ${top.key} ×${top.value}',
    entity: top.key,
    kind: GraphInsightKind.place,
  );
}

List<GraphInsight> _milestones(int nodeCount, bool isKo) {
  const thresholds = [25, 50, 100, 250, 500, 1000];
  for (final t in thresholds.reversed) {
    if (nodeCount >= t) {
      return [
        GraphInsight(
          message: isKo ? '노드 $t 달성' : 'Nodes $t',
          kind: GraphInsightKind.milestone,
        ),
      ];
    }
  }
  return const [];
}
