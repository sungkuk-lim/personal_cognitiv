import '../../models/memory.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_graph_semantics.dart';
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

class ReplayInsightCard {
  const ReplayInsightCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.memoryCount,
    required this.focusKeyword,
  });

  final ReplayInsightKind kind;
  final String title;
  final String subtitle;
  final int memoryCount;
  final String focusKeyword;
}

/// 회상 상단 — 인물·장소·이벤트·감정·음식·취미 집계 카드.
List<ReplayInsightCard> buildReplayInsightCards(
  List<Memory> memories, {
  required String localeCode,
  int maxCards = 8,
}) {
  if (memories.isEmpty) return [];

  final eventCounts = <String, int>{};
  final personCounts = <String, int>{};
  final placeCounts = <String, int>{};
  final orgCounts = <String, int>{};
  final emotionCounts = <String, int>{};
  final foodCounts = <String, int>{};
  final hobbyCounts = <String, int>{};

  for (final memory in memories) {
    final bundle = extractMemoryEntities(memory, localeCode: localeCode);
    if (bundle.hasEventHub) {
      eventCounts[bundle.eventTitle] = (eventCounts[bundle.eventTitle] ?? 0) + 1;
    }
    for (final p in bundle.people) {
      personCounts[p] = (personCounts[p] ?? 0) + 1;
    }
    for (final p in bundle.places) {
      placeCounts[p] = (placeCounts[p] ?? 0) + 1;
    }
    for (final o in bundle.organizations) {
      orgCounts[o] = (orgCounts[o] ?? 0) + 1;
    }
    for (final e in emotionTagsForMemory(memory, localeCode: localeCode)) {
      emotionCounts[e] = (emotionCounts[e] ?? 0) + 1;
    }
    for (final f in foodTagsForMemory(memory)) {
      foodCounts[f] = (foodCounts[f] ?? 0) + 1;
    }
    for (final h in hobbyTagsForMemory(memory)) {
      hobbyCounts[h] = (hobbyCounts[h] ?? 0) + 1;
    }
  }

  final cards = <ReplayInsightCard>[];

  void addTop(
    Map<String, int> counts,
    ReplayInsightKind kind,
    String Function(String title, int count) subtitleFor,
  ) {
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(2)) {
      if (e.value < 1) continue;
      cards.add(ReplayInsightCard(
        kind: kind,
        title: e.key,
        subtitle: subtitleFor(e.key, e.value),
        memoryCount: e.value,
        focusKeyword: e.key,
      ));
    }
  }

  if (localeCode == 'ko') {
    addTop(emotionCounts, ReplayInsightKind.emotion, (t, c) => '감정이 담긴 기억 $c건');
    addTop(personCounts, ReplayInsightKind.person, (t, c) => '함께한 기억 $c건');
    addTop(placeCounts, ReplayInsightKind.place, (t, c) => '방문·관련 $c건');
    addTop(eventCounts, ReplayInsightKind.event, (t, c) => '관련 기억 $c건');
    addTop(foodCounts, ReplayInsightKind.food, (t, c) => '맛·음식 기록 $c건');
    addTop(hobbyCounts, ReplayInsightKind.hobby, (t, c) => '취미 기록 $c건');
    addTop(orgCounts, ReplayInsightKind.organization, (t, c) => '활동 기록 $c건');
  } else {
    addTop(emotionCounts, ReplayInsightKind.emotion, (t, c) => '$c emotional memories');
    addTop(personCounts, ReplayInsightKind.person, (t, c) => '$c shared memories');
    addTop(placeCounts, ReplayInsightKind.place, (t, c) => '$c visits');
    addTop(eventCounts, ReplayInsightKind.event, (t, c) => '$c memories');
    addTop(foodCounts, ReplayInsightKind.food, (t, c) => '$c food moments');
    addTop(hobbyCounts, ReplayInsightKind.hobby, (t, c) => '$c hobby logs');
    addTop(orgCounts, ReplayInsightKind.organization, (t, c) => '$c activities');
  }

  cards.sort((a, b) {
    final imp = b.memoryCount.compareTo(a.memoryCount);
    if (imp != 0) return imp;
    return a.title.compareTo(b.title);
  });
  return cards.take(maxCards).toList();
}
