import '../../models/memory.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_graph_semantics.dart';
import '../../utils/memory_participation_extract.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../utils/memory_theme_tags.dart';

enum ReplayInsightKind {
  event,
  person,
  place,
  organization,
  emotion,
  food,
  hobby,
}

/// 패턴 하이라이트 — 동일 엔티티가 [kReplayInsightMinMemoryCount]건 이상일 때만 노출.
const int kReplayInsightMinMemoryCount = 2;

class ReplayInsightCard {
  const ReplayInsightCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.memoryCount,
    required this.focusKeyword,
    this.memoryIds = const {},
  });

  final ReplayInsightKind kind;
  final String title;
  final String subtitle;
  final int memoryCount;
  final String focusKeyword;
  final Set<String> memoryIds;
}

class _InsightStat {
  _InsightStat(this.kind);

  ReplayInsightKind kind;
  final Set<String> memoryIds = {};
}

/// 회상 상단 — 반복·패턴이 있는 인물·장소·이벤트만 집계 카드로 표시.
///
/// 기억 1건에서 추출된 「나」「아들」「이벤트」처럼 내용이 겹치는 칩은 만들지 않습니다.
List<ReplayInsightCard> buildReplayInsightCards(
  List<Memory> memories, {
  required String localeCode,
  int maxCards = 8,
}) {
  if (memories.isEmpty) return [];

  final stats = <String, _InsightStat>{};

  void bump(String keyword, ReplayInsightKind kind, String memoryId) {
    final key = keyword.trim();
    if (key.isEmpty) return;
    if (kind == ReplayInsightKind.person && isSelfPersonLabel(key, localeCode)) return;
    final stat = stats.putIfAbsent(key, () => _InsightStat(kind));
    if (replayInsightKindPriority(kind) < replayInsightKindPriority(stat.kind)) {
      stat.kind = kind;
    }
    stat.memoryIds.add(memoryId);
  }

  for (final memory in memories) {
    final bundle = extractMemoryEntities(memory, localeCode: localeCode);
    if (bundle.hasEventHub) {
      bump(bundle.eventTitle, ReplayInsightKind.event, memory.id);
    }
    for (final p in bundle.people) {
      bump(p, ReplayInsightKind.person, memory.id);
    }
    for (final p in bundle.places) {
      bump(p, ReplayInsightKind.place, memory.id);
    }
    for (final o in bundle.organizations) {
      bump(o, ReplayInsightKind.organization, memory.id);
    }
    for (final e in emotionTagsForMemory(memory, localeCode: localeCode)) {
      bump(e, ReplayInsightKind.emotion, memory.id);
    }
    for (final f in foodTagsForMemory(memory)) {
      bump(f, ReplayInsightKind.food, memory.id);
    }
    for (final h in hobbyTagsForMemory(memory)) {
      bump(h, ReplayInsightKind.hobby, memory.id);
    }
  }

  final cards = <ReplayInsightCard>[];
  for (final entry in stats.entries) {
    final ids = entry.value.memoryIds;
    if (ids.length < kReplayInsightMinMemoryCount) continue;
    final kind = entry.value.kind;
    cards.add(ReplayInsightCard(
      kind: kind,
      title: entry.key,
      subtitle: _insightSubtitle(kind, entry.key, ids.length, localeCode),
      memoryCount: ids.length,
      focusKeyword: entry.key,
      memoryIds: ids,
    ));
  }

  return dedupeReplayInsightCards(cards).take(maxCards).toList();
}

String _insightSubtitle(
  ReplayInsightKind kind,
  String title,
  int count,
  String localeCode,
) {
  if (localeCode == 'ko') {
    return switch (kind) {
      ReplayInsightKind.emotion => '감정이 담긴 기억 $count건',
      ReplayInsightKind.person => '함께한 기억 $count건',
      ReplayInsightKind.place => '방문·관련 $count건',
      ReplayInsightKind.event => '관련 기억 $count건',
      ReplayInsightKind.food => '맛·음식 기록 $count건',
      ReplayInsightKind.hobby => '취미 기록 $count건',
      ReplayInsightKind.organization => '활동 기록 $count건',
    };
  }
  return switch (kind) {
    ReplayInsightKind.emotion => '$count emotional memories',
    ReplayInsightKind.person => '$count shared memories',
    ReplayInsightKind.place => '$count visits',
    ReplayInsightKind.event => '$count memories',
    ReplayInsightKind.food => '$count food moments',
    ReplayInsightKind.hobby => '$count hobby logs',
    ReplayInsightKind.organization => '$count activities',
  };
}

/// 키워드와 연결된 사용자 기억 ID — 하이라이트 재생·중복 제거에 사용.
Set<String> memoryIdsForInsightKeyword(
  List<Memory> memories,
  String keyword, {
  required String localeCode,
}) {
  final label = keyword.trim();
  if (label.isEmpty) return const {};
  return memories
      .where((m) => memoryMatchesKeyword(m, label, localeCode: localeCode))
      .map((m) => m.id)
      .toSet();
}

int replayInsightKindPriority(ReplayInsightKind kind) => switch (kind) {
      ReplayInsightKind.person => 0,
      ReplayInsightKind.place => 1,
      ReplayInsightKind.event => 2,
      ReplayInsightKind.emotion => 3,
      ReplayInsightKind.hobby => 4,
      ReplayInsightKind.food => 5,
      ReplayInsightKind.organization => 6,
    };

bool replayInsightCardIsBetter(ReplayInsightCard candidate, ReplayInsightCard incumbent) {
  final priorityDiff =
      replayInsightKindPriority(candidate.kind) - replayInsightKindPriority(incumbent.kind);
  if (priorityDiff != 0) return priorityDiff < 0;
  if (candidate.memoryCount != incumbent.memoryCount) {
    return candidate.memoryCount > incumbent.memoryCount;
  }
  return candidate.title.compareTo(incumbent.title) < 0;
}

/// 동일 기억 묶음을 가리키는 카드는 하나만 — 인물·장소 우선.
List<ReplayInsightCard> dedupeReplayInsightCards(List<ReplayInsightCard> cards) {
  if (cards.length <= 1) {
    return [...cards]..sort(_compareInsightCards);
  }

  final bestByMemorySet = <String, ReplayInsightCard>{};
  for (final card in cards) {
    final key = _memorySetKey(card.memoryIds);
    final prev = bestByMemorySet[key];
    if (prev == null || replayInsightCardIsBetter(card, prev)) {
      bestByMemorySet[key] = card;
    }
  }

  return bestByMemorySet.values.toList()..sort(_compareInsightCards);
}

int _compareInsightCards(ReplayInsightCard a, ReplayInsightCard b) {
  final imp = b.memoryCount.compareTo(a.memoryCount);
  if (imp != 0) return imp;
  final kind = replayInsightKindPriority(a.kind).compareTo(replayInsightKindPriority(b.kind));
  if (kind != 0) return kind;
  return a.title.compareTo(b.title);
}

String _memorySetKey(Set<String> ids) {
  if (ids.isEmpty) return '';
  return (ids.toList()..sort()).join('\u0001');
}
