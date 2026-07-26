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
import '../../utils/memory_graph_semantics.dart';
import '../../utils/memory_grouping.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_video_paths.dart';
import 'graph_chat_save.dart';
import 'graph_layout.dart';

/// 노드와 직접 연결된 기억 목록.
List<Memory> connectedMemoriesForNode({
  required GraphNodeData node,
  required List<Memory> allMemories,
  required List<GraphEdgeData> edges,
  String localeCode = 'ko',
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
    final slug = node.id.replaceFirst('event_hub_', '');
    final matched = <Memory>[];
    for (final memory in allMemories) {
      if (!isLayoutPrimaryMemory(memory)) continue;
      final hub = eventHubForMemory(memory);
      final bundle = extractMemoryEntities(memory, localeCode: localeCode);
      final key = eventGroupKeyForMemory(
        memory: memory,
        bundle: bundle,
        storedHub: hub,
        localeCode: localeCode,
      );
      final id = key.startsWith('title::')
          ? key.substring('title::'.length)
          : key.substring('day::'.length);
      if (id == slug) {
        matched.add(memory);
        continue;
      }
      // 계층 루트 타이틀(우리 관계·ABC그룹 등)이 본문에 있으면 포함
      final title = node.title.trim();
      if (title.isNotEmpty &&
          (memory.content.contains(title) || memory.summary.contains(title))) {
        matched.add(memory);
      }
    }
    if (matched.isNotEmpty) {
      matched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return matched;
    }
    // slug가 실제 memory id인 레거시 케이스
    final legacy = byId[slug];
    return legacy != null ? [legacy] : [];
  }

  if (node.id.startsWith('entity_note_')) {
    final id = node.id.replaceFirst('entity_note_', '');
    final m = byId[id];
    return m != null ? [m] : [];
  }

  // 사람/장소 위성: 제목이 본문에 있는 기억
  final title = node.title.trim();
  if (title.isNotEmpty &&
      (node.kind == GraphNodeKind.person ||
          node.kind == GraphNodeKind.place ||
          node.kind == GraphNodeKind.event ||
          node.kind == GraphNodeKind.eventHub ||
          node.kind == GraphNodeKind.organization ||
          node.kind == GraphNodeKind.activity)) {
    final byTitle = allMemories
        .where(isLayoutPrimaryMemory)
        .where(
          (m) => m.content.contains(title) || m.summary.contains(title),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (byTitle.isNotEmpty) return byTitle;
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

bool _isHubMediaAggregateNode(GraphNodeData node) {
  return node.id.startsWith('group_') ||
      node.id.startsWith('event_hub_') ||
      node.id.startsWith('focus_hub_') ||
      node.kind == GraphNodeKind.eventHub ||
      node.kind == GraphNodeKind.group;
}

GraphNodeMediaInfo _mediaInfoForMemoryId(
  String memoryId, {
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
}) {
  return GraphNodeMediaInfo(
    thumbnailPath: primaryMediaThumbForMemoryId(memoryId, imagePaths, videoPaths),
    photoCount: imageCountForMemoryId(memoryId, imagePaths),
    hasVideo: memoryHasVideo(memoryId, videoPaths),
  );
}

GraphNodeMediaInfo _mediaInfoFromMemories({
  required Iterable<Memory> memories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
}) {
  Memory? newest;
  var photos = 0;
  var hasVideo = false;
  for (final memory in memories) {
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
  if (newest == null && photos == 0 && !hasVideo) return GraphNodeMediaInfo.empty;
  return GraphNodeMediaInfo(
    thumbnailPath: newest == null
        ? null
        : primaryMediaThumbForMemoryId(newest.id, imagePaths, videoPaths),
    photoCount: photos,
    hasVideo: hasVideo,
  );
}

/// 관계망 노드에 표시할 미디어 썸네일 (기억·허브·전용 앵커 메모만).
String? primaryMediaThumbForGraphNode({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
  List<GraphEdgeData> edges = const [],
  String localeCode = 'ko',
}) {
  return buildGraphNodeMediaIndex(
    nodes: [node],
    memories: memories,
    imagePaths: imagePaths,
    videoPaths: videoPaths,
    edges: edges,
    localeCode: localeCode,
  )[node.id]
      ?.thumbnailPath;
}

int photoCountForGraphNode({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
  List<GraphEdgeData> edges = const [],
  String localeCode = 'ko',
}) {
  return buildGraphNodeMediaIndex(
    nodes: [node],
    memories: memories,
    imagePaths: imagePaths,
    videoPaths: const {},
    edges: edges,
    localeCode: localeCode,
  )[node.id]
      ?.photoCount ??
      0;
}

bool graphNodeHasVideo({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, List<String>> videoPaths,
  List<GraphEdgeData> edges = const [],
  String localeCode = 'ko',
}) {
  return buildGraphNodeMediaIndex(
    nodes: [node],
    memories: memories,
    imagePaths: const {},
    videoPaths: videoPaths,
    edges: edges,
    localeCode: localeCode,
  )[node.id]
      ?.hasVideo ??
      false;
}

/// 노드별 미디어 정보를 한 번에 계산해 스크롤·pan 중 O(n²) 조회를 막습니다.
///
/// - 기억/엔티티노트: 해당 기억 미디어만
/// - 그룹·이벤트·포커스 허브: 그 허브에 속한 기억 미디어만
/// - 사람·장소·활동 등 위성: 그 노드에 직접 붙인 앵커 미디어만
///   (회상에서 올린 미디어가 모든 위성에 퍼지지 않음)
Map<String, GraphNodeMediaInfo> buildGraphNodeMediaIndex({
  required List<GraphNodeData> nodes,
  required List<Memory> memories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
  List<GraphEdgeData> edges = const [],
  String localeCode = 'ko',
}) {
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

  GraphNodeMediaInfo infoForAnchor(String anchorId) {
    final newest = anchorNewest[anchorId];
    if (newest == null) return GraphNodeMediaInfo.empty;
    return GraphNodeMediaInfo(
      thumbnailPath: primaryMediaThumbForMemoryId(newest.id, imagePaths, videoPaths),
      photoCount: anchorPhotoCount[anchorId] ?? 0,
      hasVideo: anchorHasVideo[anchorId] ?? false,
    );
  }

  final result = <String, GraphNodeMediaInfo>{};
  for (final node in nodes) {
    if (node.id.startsWith('memory_') || node.id.startsWith('entity_note_')) {
      final memoryId = node.id.replaceFirst(RegExp(r'^(memory_|entity_note_)'), '');
      result[node.id] = _mediaInfoForMemoryId(
        memoryId,
        imagePaths: imagePaths,
        videoPaths: videoPaths,
      );
      continue;
    }

    // 허브만 소속 기억 미디어를 집계. 위성에는 전파하지 않는다.
    if (_isHubMediaAggregateNode(node)) {
      final hubMedia = _mediaInfoFromMemories(
        memories: connectedMemoriesForNode(
          node: node,
          allMemories: memories,
          edges: edges,
          localeCode: localeCode,
        ),
        imagePaths: imagePaths,
        videoPaths: videoPaths,
      );
      final anchorId = canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());
      final anchorMedia = infoForAnchor(anchorId);
      if (hubMedia.hasVideo || hubMedia.photoCount > 0 || hubMedia.thumbnailPath != null) {
        result[node.id] = GraphNodeMediaInfo(
          thumbnailPath: anchorMedia.thumbnailPath ?? hubMedia.thumbnailPath,
          photoCount: hubMedia.photoCount + anchorMedia.photoCount,
          hasVideo: hubMedia.hasVideo || anchorMedia.hasVideo,
        );
      } else {
        result[node.id] = anchorMedia;
      }
      continue;
    }

    // 위성·기타 노드: 선택한 노드에 직접 붙인 앵커 미디어만
    final anchorId = canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());
    result[node.id] = infoForAnchor(anchorId);
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
