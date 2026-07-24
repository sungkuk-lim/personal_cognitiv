import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_grouping.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_video_paths.dart';
import 'graph_chat_save.dart';
import 'graph_layout.dart';

/// 노드와 직접 연결된 기억 목록.
List<Memory> connectedMemoriesForNode({  required GraphNodeData node,
  required List<Memory> allMemories,
  required List<GraphEdgeData> edges,
}) {
  final byId = {for (final m in allMemories) m.id: m};

  if (node.id.startsWith('memory_')) {
    final id = node.id.replaceFirst('memory_', '');
    final m = byId[id];
    return m != null ? [m] : [];
  }

  if (node.id.startsWith('group_')) {
    final clusterId = node.id.replaceFirst('group_', '');
    return allMemories
        .where((m) => isLayoutPrimaryMemory(m) && clusterKeyForMemory(m).id == clusterId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  if (node.id.startsWith('focus_hub_')) {
    final keyword = node.id.replaceFirst('focus_hub_', '');
    return allMemories.where((m) => memoryMatchesKeyword(m, keyword)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  if (node.id.startsWith('event_hub_')) {
    final id = node.id.replaceFirst('event_hub_', '');
    final m = byId[id];
    return m != null ? [m] : [];
  }

  if (node.id.startsWith('entity_note_')) {
    final id = node.id.replaceFirst('entity_note_', '');
    final m = byId[id];
    return m != null ? [m] : [];
  }

  final linkedIds = _memoryIdsReachableFromNode(node.id, edges);
  return linkedIds
      .map((id) => byId[id])
      .whereType<Memory>()
      .where(isLayoutPrimaryMemory)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// 이벤트 허브·위성 노드 등 간접 연결 기억까지 탐색합니다.
Set<String> _memoryIdsReachableFromNode(String startId, List<GraphEdgeData> edges) {
  final memoryIds = <String>{};
  final queue = <String>[startId];
  final seen = <String>{};

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    if (!seen.add(current)) continue;

    if (current.startsWith('memory_')) {
      memoryIds.add(current.replaceFirst('memory_', ''));
      continue;
    }

    for (final edge in edges) {
      final neighbor = edge.fromId == current
          ? edge.toId
          : edge.toId == current
              ? edge.fromId
              : null;
      if (neighbor != null && !seen.contains(neighbor)) {
        queue.add(neighbor);
      }
    }
  }
  return memoryIds;
}

/// 관계망 AI 저장용 — 그래프 선이 없어도 본 기억을 추론합니다.
List<Memory> resolveGraphChatContextMemories({
  required GraphNodeData node,
  required List<Memory> allMemories,
  required List<GraphEdgeData> edges,
}) {
  final linked = connectedMemoriesForNode(
    node: node,
    allMemories: allMemories,
    edges: edges,
  ).where(isLayoutPrimaryMemory).toList();
  if (linked.isNotEmpty) return linked;

  final primary = allMemories.where(isLayoutPrimaryMemory).toList();
  final inferred = inferPrimaryMemoryForGraphAnchor(node.title.trim(), primary);
  if (inferred != null) return [inferred];

  if (node.id.startsWith('focus_hub_')) {
    final keyword = node.id.replaceFirst('focus_hub_', '');
    return primary.where((m) => memoryMatchesKeyword(m, keyword)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  return const [];
}

/// 저장·안내용 기억 제목.
String memoryLabelForGraphSave(Memory memory) {
  final summary = memory.summary.trim();
  if (summary.isNotEmpty) {
    return summary.length > 28 ? '${summary.substring(0, 27)}…' : summary;
  }
  final content = memory.content.trim();
  if (content.isEmpty) return memory.id;
  final firstLine = content.split(RegExp(r'[\n\r]+')).first.trim();
  return firstLine.length > 28 ? '${firstLine.substring(0, 27)}…' : firstLine;
}

String graphNodeAiHook({
  required GraphNodeData node,
  required Map<String, String> t,
  required List<Memory> memories,
}) {
  return switch (node.kind) {
    GraphNodeKind.person =>
      t['graph_node_ai_hook_person']!.replaceAll('{name}', node.title),
    GraphNodeKind.pet =>
      t['graph_node_ai_hook_entity']!
          .replaceAll('{name}', node.title)
          .replaceAll('{kind}', node.subtitle),
    GraphNodeKind.place =>
      t['graph_node_ai_hook_place']!.replaceAll('{name}', node.title),
    GraphNodeKind.group =>
      t['graph_node_ai_hook_group']!.replaceAll('{count}', '${memories.length}'),
    GraphNodeKind.eventHub =>
      t['graph_node_ai_hook_entity']!
          .replaceAll('{name}', node.title)
          .replaceAll('{kind}', node.subtitle),
    GraphNodeKind.memory =>
      t['graph_node_ai_hook_memory']!.replaceAll('{title}', node.title),
    GraphNodeKind.activity ||
    GraphNodeKind.event ||
    GraphNodeKind.content ||
    GraphNodeKind.interest ||
    GraphNodeKind.food ||
    GraphNodeKind.hobby ||
    GraphNodeKind.organization ||
    GraphNodeKind.goal ||
    GraphNodeKind.emotion =>
      t['graph_node_ai_hook_entity']!
          .replaceAll('{name}', node.title)
          .replaceAll('{kind}', node.subtitle),
  };
}

List<String> graphNodeAiSuggestions({
  required GraphNodeData node,
  required Map<String, String> t,
}) {
  final keys = switch (node.kind) {
    GraphNodeKind.person => ['graph_node_ai_q_person_1', 'graph_node_ai_q_person_2', 'graph_node_ai_q_person_3'],
    GraphNodeKind.place => ['graph_node_ai_q_place_1', 'graph_node_ai_q_place_2', 'graph_node_ai_q_place_3'],
    GraphNodeKind.memory => ['graph_node_ai_q_memory_1', 'graph_node_ai_q_memory_2', 'graph_node_ai_q_memory_3'],
    GraphNodeKind.group => ['graph_node_ai_q_group_1', 'graph_node_ai_q_group_2', 'graph_node_ai_q_group_3'],
    _ => ['graph_node_ai_q_default_1', 'graph_node_ai_q_default_2', 'graph_node_ai_q_default_3'],
  };
  return keys.map((k) => t[k]!.replaceAll('{name}', node.title)).toList();
}

/// 관계망 노드에 표시할 미디어 썸네일 (기억·이벤트 허브·인물 앵커 메모).
String? primaryMediaThumbForGraphNode({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
}) {
  if (node.id.startsWith('memory_') || node.id.startsWith('event_hub_') || node.id.startsWith('entity_note_')) {
    final memoryId = node.id.replaceFirst(RegExp(r'^(memory_|event_hub_|entity_note_)'), '');
    return primaryMediaThumbForMemoryId(memoryId, imagePaths, videoPaths);
  }

  final anchorId = canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());
  Memory? newest;
  for (final memory in memories) {
    if (graphNoteAnchorNodeId(memory) != anchorId) continue;
    final thumb = primaryMediaThumbForMemoryId(memory.id, imagePaths, videoPaths);
    if (thumb == null) continue;
    if (newest == null || memory.createdAt.isAfter(newest.createdAt)) {
      newest = memory;
    }
  }
  if (newest != null) {
    return primaryMediaThumbForMemoryId(newest.id, imagePaths, videoPaths);
  }
  return null;
}

int photoCountForGraphNode({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
}) {
  if (node.id.startsWith('memory_') || node.id.startsWith('event_hub_') || node.id.startsWith('entity_note_')) {
    final memoryId = node.id.replaceFirst(RegExp(r'^(memory_|event_hub_|entity_note_)'), '');
    return imageCountForMemoryId(memoryId, imagePaths);
  }

  final anchorId = canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());
  var count = 0;
  for (final memory in memories) {
    if (graphNoteAnchorNodeId(memory) == anchorId) {
      count += imageCountForMemoryId(memory.id, imagePaths);
    }
  }
  return count;
}

bool graphNodeHasVideo({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, List<String>> videoPaths,
}) {
  if (node.id.startsWith('memory_') || node.id.startsWith('event_hub_') || node.id.startsWith('entity_note_')) {
    final memoryId = node.id.replaceFirst(RegExp(r'^(memory_|event_hub_|entity_note_)'), '');
    return memoryHasVideo(memoryId, videoPaths);
  }

  final anchorId = canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());
  for (final memory in memories) {
    if (graphNoteAnchorNodeId(memory) == anchorId && memoryHasVideo(memory.id, videoPaths)) {
      return true;
    }
  }
  return false;
}

class GraphNodeMediaInfo {
  const GraphNodeMediaInfo({
    this.thumbnailPath,
    this.photoCount = 0,
    this.hasVideo = false,
  });

  static const empty = GraphNodeMediaInfo();

  final String? thumbnailPath;
  final int photoCount;
  final bool hasVideo;
}

/// 노드별 미디어 정보를 한 번에 계산해 스크롤·pan 중 O(n²) 조회를 막습니다.
///
/// 위성(사람·장소·활동 등)은 전용 앵커 메모가 없으면 **관련 기억**의
/// 최신 사진·동영상을 썸네일로 사용합니다.
Map<String, GraphNodeMediaInfo> buildGraphNodeMediaIndex({
  required List<GraphNodeData> nodes,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
  List<GraphEdgeData> edges = const [],
  String localeCode = 'ko',
}) {
  final primaryMemories = memories.where(isLayoutPrimaryMemory).toList();
  final anchorNewest = <String, Memory>{};
  final anchorPhotoCount = <String, int>{};
  final anchorHasVideo = <String, bool>{};

  for (final memory in memories) {
    final anchorId = graphNoteAnchorNodeId(memory);
    if (anchorId == null) continue;
    final prev = anchorNewest[anchorId];
    if (prev == null || memory.createdAt.isAfter(prev.createdAt)) {
      anchorNewest[anchorId] = memory;
    }
    anchorPhotoCount[anchorId] =
        (anchorPhotoCount[anchorId] ?? 0) + imageCountForMemoryId(memory.id, imagePaths);
    if (memoryHasVideo(memory.id, videoPaths)) {
      anchorHasVideo[anchorId] = true;
    }
  }

  // 라벨 → 관련 기억(미디어 있는 것만, 최신 우선) — 위성 썸네일용
  final labelNewestWithMedia = <String, Memory>{};
  final labelPhotoCount = <String, int>{};
  final labelHasVideo = <String, bool>{};

  void considerLabel(String rawLabel, Memory memory) {
    final label = rawLabel.trim();
    if (label.isEmpty) return;
    final key = label.toLowerCase();
    final photos = imageCountForMemoryId(memory.id, imagePaths);
    final hasVideo = memoryHasVideo(memory.id, videoPaths);
    if (photos == 0 && !hasVideo) return;
    final prev = labelNewestWithMedia[key];
    if (prev == null || memory.createdAt.isAfter(prev.createdAt)) {
      labelNewestWithMedia[key] = memory;
    }
    labelPhotoCount[key] = (labelPhotoCount[key] ?? 0) + photos;
    if (hasVideo) labelHasVideo[key] = true;
  }

  for (final memory in primaryMemories) {
    final bundle = extractMemoryEntities(memory, localeCode: localeCode);
    for (final p in bundle.people) {
      considerLabel(p, memory);
    }
    for (final p in bundle.places) {
      considerLabel(p, memory);
    }
    for (final a in bundle.activities) {
      considerLabel(a, memory);
    }
    for (final e in bundle.events) {
      considerLabel(e, memory);
    }
    for (final o in bundle.organizations) {
      considerLabel(o, memory);
    }
  }

  final result = <String, GraphNodeMediaInfo>{};
  for (final node in nodes) {
    if (node.id.startsWith('memory_') ||
        node.id.startsWith('event_hub_') ||
        node.id.startsWith('entity_note_')) {
      final memoryId = node.id.replaceFirst(RegExp(r'^(memory_|event_hub_|entity_note_)'), '');
      result[node.id] = GraphNodeMediaInfo(
        thumbnailPath: primaryMediaThumbForMemoryId(memoryId, imagePaths, videoPaths),
        photoCount: imageCountForMemoryId(memoryId, imagePaths),
        hasVideo: memoryHasVideo(memoryId, videoPaths),
      );
      continue;
    }

    if (node.id.startsWith('group_')) {
      Memory? newest;
      var photos = 0;
      var hasVideo = false;
      for (final memory in connectedMemoriesForNode(
        node: node,
        allMemories: memories,
        edges: edges,
      )) {
        final p = imageCountForMemoryId(memory.id, imagePaths);
        final v = memoryHasVideo(memory.id, videoPaths);
        photos += p;
        if (v) hasVideo = true;
        if (p > 0 || v) {
          if (newest == null || memory.createdAt.isAfter(newest.createdAt)) {
            newest = memory;
          }
        }
      }
      result[node.id] = GraphNodeMediaInfo(
        thumbnailPath: newest == null
            ? null
            : primaryMediaThumbForMemoryId(newest.id, imagePaths, videoPaths),
        photoCount: photos,
        hasVideo: hasVideo,
      );
      continue;
    }

    final anchorId = canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());
    final newestAnchor = anchorNewest[anchorId];
    if (newestAnchor != null) {
      result[node.id] = GraphNodeMediaInfo(
        thumbnailPath: primaryMediaThumbForMemoryId(newestAnchor.id, imagePaths, videoPaths),
        photoCount: anchorPhotoCount[anchorId] ?? 0,
        hasVideo: anchorHasVideo[anchorId] ?? false,
      );
      continue;
    }

    // 관련 기억 폴백 (사람·장소·활동 위성)
    final labelKey = node.title.trim().toLowerCase();
    final related = labelNewestWithMedia[labelKey];
    if (related != null) {
      result[node.id] = GraphNodeMediaInfo(
        thumbnailPath: primaryMediaThumbForMemoryId(related.id, imagePaths, videoPaths),
        photoCount: labelPhotoCount[labelKey] ?? 0,
        hasVideo: labelHasVideo[labelKey] ?? false,
      );
      continue;
    }

    // 그래프 선으로 연결된 기억
    if (edges.isNotEmpty) {
      Memory? newest;
      var photos = 0;
      var hasVideo = false;
      for (final memory in connectedMemoriesForNode(
        node: node,
        allMemories: memories,
        edges: edges,
      )) {
        final p = imageCountForMemoryId(memory.id, imagePaths);
        final v = memoryHasVideo(memory.id, videoPaths);
        photos += p;
        if (v) hasVideo = true;
        if (p > 0 || v) {
          if (newest == null || memory.createdAt.isAfter(newest.createdAt)) {
            newest = memory;
          }
        }
      }
      if (newest != null || photos > 0 || hasVideo) {
        result[node.id] = GraphNodeMediaInfo(
          thumbnailPath: newest == null
              ? null
              : primaryMediaThumbForMemoryId(newest.id, imagePaths, videoPaths),
          photoCount: photos,
          hasVideo: hasVideo,
        );
        continue;
      }
    }

    result[node.id] = GraphNodeMediaInfo.empty;
  }
  return result;
}

String buildGraphNodeAiSystemPrompt({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
  required String languageName,
}) {
  final memoryBlocks = memories.take(8).map((m) {
    final fragment = fragments[m.id];
    final meaning = fragment != null && fragment.isUsable ? fragment.meaningTitle : m.summary;
    return '- [${m.id}] ${meaning.isNotEmpty ? meaning : m.content}';
  }).join('\n');

  return '''
You are MemoryOS, a warm personal memory companion inside a relationship graph.
The user tapped a graph node. Continue the conversation naturally in $languageName.
Ask one thoughtful follow-up at a time. Reference their stored memories — never invent facts.
If they share new details, acknowledge and invite more.
Node: ${node.title} (${node.subtitle})
Connected memories:
$memoryBlocks
''';
}

/// 인물·장소·활동 노드 탭 → 해당 앵커 전용 사진·동영상 상세 (관련 기억 칩 없음).
Future<void> showGraphEntityMediaSheet(
  BuildContext context,
  WidgetRef ref, {
  required GraphNodeData node,
  required Map<String, List<String>> imagePaths,
}) async {
  HapticFeedback.mediumImpact();
  final anchorId = canonicalGraphAnchorNodeIdForNode(node);
  final memories = ref.read(memoryListProvider);
  final saved = findGraphAnchorMemory(memories, anchorId);
  final anchorMemory = saved ??
      buildMediaOnlyGraphNote(
        anchorNodeId: anchorId,
        anchorLabel: node.title.trim(),
        localeCode: ref.read(languageProvider).languageCode,
        relatedMemoryId: inferPrimaryMemoryForGraphAnchor(
          node.title.trim(),
          memories.where(isLayoutPrimaryMemory).toList(),
        )?.id,
      );

  if (!context.mounted) return;
  final videoPaths = ref.read(memoryVideoPathsProvider);
  showMemoryDetailSheet(
    context,
    anchorMemory,
    imagePaths: imagePaths,
    options: MemoryDetailPresets.graphEntityMedia(
      node: node,
      hasVideo: saved != null && memoryHasVideo(saved.id, videoPaths),
    ),
  );
}
