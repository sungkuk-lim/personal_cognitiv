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
    GraphNodeKind.activity || GraphNodeKind.goal || GraphNodeKind.emotion =>
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
