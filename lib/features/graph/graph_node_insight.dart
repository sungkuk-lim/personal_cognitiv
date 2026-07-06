import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import '../../utils/graph_meaning.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../utils/memory_participation_extract.dart';
import 'graph_layout.dart';

class LabelCount {
  const LabelCount({required this.label, required this.count});
  final String label;
  final int count;
}

/// 관계망 노드 탭 — #1 인사이트 + #2 타임라인 + #4 추천 + #5 코치 + #6 테마 허브.
class GraphNodeInsight {
  const GraphNodeInsight({
    required this.totalCount,
    required this.recent30Count,
    required this.recent90Count,
    this.lastMemoryAt,
    this.daysSinceLast,
    this.topPlaces = const [],
    this.topActivities = const [],
    this.topCoPeople = const [],
    this.topEmotions = const [],
    this.memoryDensityScore = 0,
    this.coachNudgeKey,
    this.coachNudgeDays,
    this.timelineMemories = const [],
    this.recommendedMemories = const [],
    this.themeHubLabel = '',
    this.summaryLine = '',
  });

  final int totalCount;
  final int recent30Count;
  final int recent90Count;
  final DateTime? lastMemoryAt;
  final int? daysSinceLast;
  final List<LabelCount> topPlaces;
  final List<LabelCount> topActivities;
  final List<LabelCount> topCoPeople;
  final List<LabelCount> topEmotions;
  final int memoryDensityScore;
  final String? coachNudgeKey;
  final int? coachNudgeDays;
  final List<Memory> timelineMemories;
  final List<Memory> recommendedMemories;
  final String themeHubLabel;
  final String summaryLine;

  bool get hasCoachNudge => coachNudgeKey != null;
  bool get hasThemeHub => themeHubLabel.isNotEmpty;
}

GraphNodeInsight buildGraphNodeInsight({
  required GraphNodeData node,
  required List<Memory> connectedMemories,
  required List<Memory> allMemories,
  required Map<String, GraphMemoryFragment> fragments,
  required String localeCode,
}) {
  final isKo = localeCode == 'ko';
  final sorted = [...connectedMemories]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final now = DateTime.now();
  final recent30 = sorted.where((m) => m.createdAt.isAfter(now.subtract(const Duration(days: 30)))).length;
  final recent90 = sorted.where((m) => m.createdAt.isAfter(now.subtract(const Duration(days: 90)))).length;
  final lastAt = sorted.isEmpty ? null : sorted.first.createdAt;
  final daysSince = lastAt == null ? null : now.difference(lastAt).inDays;

  final places = <String, int>{};
  final activities = <String, int>{};
  final coPeople = <String, int>{};
  final emotions = <String, int>{};
  var density = 0;

  for (final memory in sorted.take(24)) {
    density += memory.entities.length.clamp(0, 6);
    if (memory.content.trim().length > 40) density += 1;
    final fragment = fragments[memory.id];
    final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: fragment);
    for (final p in bundle.places) {
      if (p != node.title) places[p] = (places[p] ?? 0) + 1;
    }
    for (final a in bundle.activities) {
      activities[a] = (activities[a] ?? 0) + 1;
    }
    for (final p in bundle.people) {
      if (p != node.title && !isSelfPersonLabel(p, localeCode)) {
        coPeople[p] = (coPeople[p] ?? 0) + 1;
      }
    }
    for (final e in bundle.emotions) {
      emotions[e] = (emotions[e] ?? 0) + 1;
    }
    if (fragment != null) {
      for (final s in fragment.satellites) {
        switch (s.kind) {
          case 'place':
            if (s.label != node.title) places[s.label] = (places[s.label] ?? 0) + 1;
          case 'person':
            if (s.label != node.title && !isSelfPersonLabel(s.label, localeCode)) {
              coPeople[s.label] = (coPeople[s.label] ?? 0) + 1;
            }
          default:
            break;
        }
      }
    }
  }

  List<LabelCount> top(Map<String, int> map, {int n = 3}) {
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(n).map((e) => LabelCount(label: e.key, count: e.value)).toList();
  }

  String? coachKey;
  int? coachDays;
  if (node.kind == GraphNodeKind.person && daysSince != null && daysSince >= 60 && sorted.isNotEmpty) {
    coachKey = 'graph_insight_coach_gap';
    coachDays = daysSince;
  }

  final themeLabel = _themeHubLabel(node, localeCode);
  final recommended = _recommendRelated(
    node: node,
    connected: sorted,
    allMemories: allMemories,
    localeCode: localeCode,
  );

  final summary = _summaryLine(
    node: node,
    total: sorted.length,
    recent30: recent30,
    lastAt: lastAt,
    topPlace: top(places).isNotEmpty ? top(places).first.label : null,
    localeCode: localeCode,
  );

  return GraphNodeInsight(
    totalCount: sorted.length,
    recent30Count: recent30,
    recent90Count: recent90,
    lastMemoryAt: lastAt,
    daysSinceLast: daysSince,
    topPlaces: top(places),
    topActivities: top(activities),
    topCoPeople: top(coPeople),
    topEmotions: top(emotions),
    memoryDensityScore: density.clamp(0, 100),
    coachNudgeKey: coachKey,
    coachNudgeDays: coachDays,
    timelineMemories: sorted.take(12).toList(),
    recommendedMemories: recommended,
    themeHubLabel: themeLabel,
    summaryLine: summary,
  );
}

String _themeHubLabel(GraphNodeData node, String localeCode) {
  final title = node.title.trim();
  if (title.isEmpty) return '';
  if (node.kind == GraphNodeKind.person) {
    return localeCode == 'ko' ? '$title와의 기억' : 'Memories with $title';
  }
  if (node.kind == GraphNodeKind.place) {
    return localeCode == 'ko' ? '$title에서의 나날' : 'Days at $title';
  }
  if (node.kind == GraphNodeKind.content || node.kind == GraphNodeKind.food) {
    return localeCode == 'ko' ? '$title이 담긴 순간' : 'Moments with $title';
  }
  return localeCode == 'ko' ? '$title 테마' : '$title theme';
}

List<Memory> _recommendRelated({
  required GraphNodeData node,
  required List<Memory> connected,
  required List<Memory> allMemories,
  required String localeCode,
}) {
  final connectedIds = connected.map((m) => m.id).toSet();
  final keyword = node.title.trim();
  if (keyword.isEmpty) return const [];

  final candidates = allMemories
      .where((m) => !connectedIds.contains(m.id))
      .where((m) => memoryMatchesKeyword(m, keyword, localeCode: localeCode))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return candidates.take(3).toList();
}

String _summaryLine({
  required GraphNodeData node,
  required int total,
  required int recent30,
  required DateTime? lastAt,
  required String? topPlace,
  required String localeCode,
}) {
  final isKo = localeCode == 'ko';
  if (total == 0) {
    return isKo ? '연결된 기억 없음' : 'No linked memories';
  }
  final lastPart = lastAt == null
      ? ''
      : isKo
          ? ' · 마지막 ${_formatShortDate(lastAt, localeCode)}'
          : ' · last ${_formatShortDate(lastAt, localeCode)}';
  if (topPlace != null && (node.kind == GraphNodeKind.person)) {
    return isKo
        ? '${node.title} · $total건 · 주로 $topPlace · 30일 $recent30건$lastPart'
        : '${node.title} · $total · mostly $topPlace · $recent30 (30d)$lastPart';
  }
  return isKo
      ? '${node.title} · $total건 · 30일 $recent30건$lastPart'
      : '${node.title} · $total · $recent30 (30d)$lastPart';
}

String _formatShortDate(DateTime dt, String localeCode) {
  if (localeCode == 'ko') return '${dt.month}월 ${dt.day}일';
  return '${dt.month}/${dt.day}';
}

String memoryTimelineTitle(Memory memory, {String localeCode = 'ko'}) {
  final meaning = graphMeaningSentence(memory, localeCode: localeCode);
  if (meaning.isNotEmpty && meaning.length <= 42) return meaning;
  final content = memory.content.trim();
  if (content.isNotEmpty) {
    return content.length > 40 ? '${content.substring(0, 39)}…' : content;
  }
  return memory.summary.trim();
}
