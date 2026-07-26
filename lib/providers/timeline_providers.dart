import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../utils/memory_entity_edit.dart';
import '../utils/memory_grouping.dart';
import '../utils/memory_place_cache.dart';
import '../utils/memory_theme_tags.dart';
import '../utils/recall_anchor.dart';
import 'app_providers.dart';
import 'memory_notifier.dart';

/// 타임라인 그룹핑 — 스크롤 중 매 build마다 재계산하지 않도록 캐시합니다.
final timelineGroupsProvider = Provider<List<MemoryTimelineGroup>>((ref) {
  final memories = ref.watch(memoryListProvider);
  return groupMemoriesForTimeline(memories);
});

/// 카드별 장소·회상 배지·키워드 — 스크롤 시 카드마다 반복 계산하지 않습니다.
class TimelineCardMeta {
  const TimelineCardMeta({
    required this.placeTitle,
    required this.recallStatus,
    required this.keywordLabels,
  });

  final String placeTitle;
  final RecallAnchorStatus recallStatus;
  final List<String> keywordLabels;
}

final timelineCardMetaProvider = Provider<Map<String, TimelineCardMeta>>((ref) {
  final memories = ref.watch(memoryListProvider);
  final localeCode = ref.watch(languageProvider).languageCode;
  final placeCache = ref.watch(memoryPlaceNamesProvider);
  final fullAddressCache = ref.watch(memoryPlaceFullAddressesProvider);

  return {
    for (final memory in memories)
      memory.id: TimelineCardMeta(
        placeTitle: displayPlaceAddress(
          memory,
          placeCache,
          fullAddressCache,
          localeCode: localeCode,
          allMemories: isGraphNoteMemory(memory) ? memories : null,
        ),
        recallStatus: recallAnchorStatus(memory, localeCode: localeCode),
        keywordLabels: displayTagsForMemory(memory, localeCode: localeCode).take(6).toList(),
      ),
  };
});

/// 타임라인 리스트에 필요한 공통 데이터를 한 번에 모읍니다.
class TimelineListSnapshot {
  const TimelineListSnapshot({
    required this.memories,
    required this.groups,
    required this.cardMeta,
    required this.locale,
    required this.translations,
    required this.imagePaths,
    required this.imageMemos,
    required this.videoPaths,
    required this.placeCache,
    required this.fullAddressCache,
  });

  final List<Memory> memories;
  final List<MemoryTimelineGroup> groups;
  final Map<String, TimelineCardMeta> cardMeta;
  final Locale locale;
  final Map<String, String> translations;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> imageMemos;
  final Map<String, List<String>> videoPaths;
  final Map<String, String> placeCache;
  final Map<String, String> fullAddressCache;
}

final timelineListSnapshotProvider = Provider<TimelineListSnapshot>((ref) {
  final memories = ref.watch(memoryListProvider);
  return TimelineListSnapshot(
    memories: memories,
    groups: ref.watch(timelineGroupsProvider),
    cardMeta: ref.watch(timelineCardMetaProvider),
    locale: ref.watch(languageProvider),
    translations: ref.watch(translationsProvider),
    imagePaths: ref.watch(memoryImagePathsProvider),
    imageMemos: ref.watch(memoryImageMemosProvider),
    videoPaths: ref.watch(memoryVideoPathsProvider),
    placeCache: ref.watch(memoryPlaceNamesProvider),
    fullAddressCache: ref.watch(memoryPlaceFullAddressesProvider),
  );
});
