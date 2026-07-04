import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memory.dart';
import '../core/prefs.dart';
import '../features/graph/graph_chat_save.dart';
import '../features/graph/graph_layout.dart';
import '../providers/app_providers.dart';
import '../providers/memory_notifier.dart';
import '../utils/graph_snapshot_store.dart';
import '../utils/memory_image_paths.dart';
import '../utils/memory_video_paths.dart';

/// 관계망 데이터 정리 결과.
class GraphCleanupReport {
  const GraphCleanupReport({
    this.repairedTypes = 0,
    this.removedEmptyMediaAnchors = 0,
    this.mergedDuplicateAnchors = 0,
    this.removedOrphanFragments = 0,
    this.clearedStalePositions = 0,
  });

  final int repairedTypes;
  final int removedEmptyMediaAnchors;
  final int mergedDuplicateAnchors;
  final int removedOrphanFragments;
  final int clearedStalePositions;

  int get total =>
      repairedTypes +
      removedEmptyMediaAnchors +
      mergedDuplicateAnchors +
      removedOrphanFragments +
      clearedStalePositions;

  bool get isEmpty => total == 0;
}

bool _anchorHasMedia(String memoryId, Map<String, List<String>> images, Map<String, List<String>> videos) {
  return imageCountForMemoryId(memoryId, images) > 0 || (videos[memoryId]?.isNotEmpty ?? false);
}

Future<GraphCleanupReport> _scanCleanup(WidgetRef ref, {required bool apply}) async {
  final prefs = ref.read(preferencesProvider);
  final memories = ref.read(memoryListProvider);
  final imagePaths = ref.read(memoryImagePathsProvider);
  final videoPaths = ref.read(memoryVideoPathsProvider);
  final notifier = ref.read(memoryListProvider.notifier);

  var repairedTypes = 0;
  var removedEmpty = 0;

  for (final memory in memories) {
    final normalized = normalizeGraphNoteMemory(memory);
    if (normalized.type != memory.type) {
      repairedTypes++;
      if (apply) await notifier.updateMemory(normalized);
    }

    if (!isGraphAnchorMediaStorage(memory)) continue;
    if (_anchorHasMedia(memory.id, imagePaths, videoPaths)) continue;
      if (graphNoteFactTitle(memory).trim().isNotEmpty) continue;

    removedEmpty++;
    if (apply) await notifier.deleteMemory(memory.id);
  }

  // 같은 앵커 graph_note 중복 — 미디어가 있는 것 하나만 남깁니다.
  final anchorGroups = <String, List<Memory>>{};
  for (final memory in apply ? ref.read(memoryListProvider) : memories) {
    if (!isGraphNoteMemory(memory) && graphNoteAnchorNodeId(memory) == null) continue;
    final anchorId = graphNoteAnchorNodeId(memory);
    if (anchorId == null) continue;
    anchorGroups.putIfAbsent(anchorId, () => []).add(memory);
  }
  var mergedAnchors = 0;
  for (final group in anchorGroups.values) {
    if (group.length < 2) continue;
    group.sort((a, b) {
      final aMedia = _anchorHasMedia(a.id, imagePaths, videoPaths) ? 1 : 0;
      final bMedia = _anchorHasMedia(b.id, imagePaths, videoPaths) ? 1 : 0;
      if (aMedia != bMedia) return bMedia.compareTo(aMedia);
      return b.createdAt.compareTo(a.createdAt);
    });
    for (var i = 1; i < group.length; i++) {
      mergedAnchors++;
      if (apply) await notifier.deleteMemory(group[i].id);
    }
  }

  final memoryIds = apply
      ? ref.read(memoryListProvider).map((m) => m.id).toSet()
      : memories.map((m) => m.id).toSet();
  var removedFragments = 0;
  for (final id in readMemoryGraphFragments(prefs).keys) {
    if (!memoryIds.contains(id)) {
      removedFragments++;
      if (apply) await removeMemoryGraphFragment(prefs, id);
    }
  }

  final layout = buildMemoryGraphLayout(
    apply ? ref.read(memoryListProvider) : memories,
    localeCode: ref.read(languageProvider).languageCode,
  );
  final validNodeIds = layout.nodes.map((n) => n.id).toSet();
  final positions = {...ref.read(graphNodePositionsProvider)};
  final clearedPositions = positions.keys.where((id) => !validNodeIds.contains(id)).length;
  if (apply && clearedPositions > 0) {
    positions.removeWhere((id, _) => !validNodeIds.contains(id));
    ref.read(graphNodePositionsProvider.notifier).state = positions;
    await saveGraphPositions(prefs, positions);
  }

  return GraphCleanupReport(
    repairedTypes: repairedTypes,
    removedEmptyMediaAnchors: removedEmpty,
    mergedDuplicateAnchors: mergedAnchors,
    removedOrphanFragments: removedFragments,
    clearedStalePositions: clearedPositions,
  );
}

/// 꼬인 관계망·내부 메모·캐시를 정리합니다.
Future<GraphCleanupReport> runGraphDataCleanup(WidgetRef ref) => _scanCleanup(ref, apply: true);

/// 정리 전 영향 건수만 미리 봅니다.
Future<GraphCleanupReport> previewGraphDataCleanup(WidgetRef ref) => _scanCleanup(ref, apply: false);
