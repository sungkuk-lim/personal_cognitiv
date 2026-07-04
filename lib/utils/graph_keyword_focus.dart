import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/graph/graph_layout.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../providers/app_providers.dart';
import 'memory_entity_extract.dart';
import 'memory_keyword_ui.dart';

List<Memory> memoriesForKeyword(List<Memory> memories, String keyword, {int maxCount = 12}) {
  final matching = memories
      .where(isUserFacingMemory)
      .where((m) => memoryMatchesKeyword(m, keyword))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return matching.take(maxCount).toList();
}

int countMemoriesForKeyword(List<Memory> memories, String keyword) {
  return memories.where(isUserFacingMemory).where((m) => memoryMatchesKeyword(m, keyword)).length;
}

GraphNodeKind graphKindForKeyword(String keyword, List<Memory> matches, {String localeCode = 'ko'}) {
  if (matches.isEmpty) return GraphNodeKind.activity;
  return switch (classifyKeyword(keyword, matches.first, localeCode: localeCode)) {
    MemoryKeywordKind.person => GraphNodeKind.person,
    MemoryKeywordKind.place => GraphNodeKind.place,
    MemoryKeywordKind.tag => GraphNodeKind.activity,
  };
}

/// 타임라인·회상 등에서 키워드 탭 → 관계망 포커스 탭으로 이동.
void openGraphKeywordFocus(WidgetRef ref, String keyword) {
  final trimmed = keyword.trim();
  if (trimmed.isEmpty) return;
  ref.read(graphFocusKeywordProvider.notifier).state = trimmed;
  ref.read(mainNavigationTabProvider.notifier).state = 2;
}

/// 회상 탭으로 이동.
void openReplayTab(WidgetRef ref) {
  ref.read(mainNavigationTabProvider.notifier).state = 3;
}

/// 검색 탭으로 이동.
void openSearchTab(WidgetRef ref) {
  ref.read(mainNavigationTabProvider.notifier).state = 1;
}

/// 검색·회상 결과에서 관계망으로 — 공통 인물·장소만 포커스합니다.
String? primaryKeywordForMemories(List<Memory> matches, String query) {
  final q = query.trim();
  if (q.isNotEmpty && matches.any((m) => memoryMatchesKeyword(m, q))) return q;

  final counts = <String, int>{};
  for (final memory in matches) {
    for (final label in userVisibleEntityLabels(memory)) {
      counts[label] = (counts[label] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return q.isEmpty ? null : q;

  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  if (sorted.length > 1 && top.value < 2) {
    return q.isEmpty ? top.key : q;
  }
  return top.key;
}

void openGraphForMemories(WidgetRef ref, List<Memory> matches, String query) {
  final keyword = primaryKeywordForMemories(matches, query);
  if (keyword == null || keyword.isEmpty) return;
  ref.read(highlightedEntitiesProvider.notifier).state = [keyword];
  openGraphKeywordFocus(ref, keyword);
}

/// 회상·상세에서 단일 기억의 관계망으로 이동합니다.
void openGraphForMemory(WidgetRef ref, Memory memory, {String? keyword}) {
  final labels = userVisibleEntityLabels(memory);
  final focus = (keyword?.trim().isNotEmpty == true)
      ? keyword!.trim()
      : (labels.isNotEmpty ? labels.first : memory.summary.trim());
  if (focus.isEmpty) return;
  ref.read(highlightedEntitiesProvider.notifier).state = labels.take(3).toList();
  openGraphKeywordFocus(ref, focus);
}
