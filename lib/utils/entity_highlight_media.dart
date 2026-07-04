import 'package:intl/intl.dart';

import '../features/graph/graph_chat_save.dart';
import '../features/graph/graph_layout.dart';
import '../features/graph/graph_node_context.dart';
import '../models/memory.dart';
import '../utils/memory_image_memos.dart';
import '../utils/memory_image_paths.dart';
import '../utils/memory_keyword_ui.dart';
import '../utils/memory_video_paths.dart';

/// 엔티티 하이라이트 슬라이드 한 장.
class EntityHighlightSlide {
  const EntityHighlightSlide({
    this.imagePath,
    this.videoPath,
    required this.memoryId,
    required this.caption,
    required this.dateLabel,
    required this.memoryTitle,
  }) : assert(imagePath != null || videoPath != null);

  final String? imagePath;
  final String? videoPath;
  final String memoryId;
  final String caption;
  final String dateLabel;
  final String memoryTitle;

  bool get isVideo => videoPath != null;
}

/// 키워드·관계망 노드와 연결된 사진·동영상을 시간순(최신 우선)으로 모읍니다.
List<EntityHighlightSlide> collectEntityHighlightSlides({
  required String entityLabel,
  required List<Memory> allMemories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> imageMemos,
  required Map<String, List<String>> videoPaths,
  GraphNodeData? node,
  List<GraphEdgeData>? edges,
  String localeCode = 'ko',
}) {
  final label = entityLabel.trim();
  if (label.isEmpty) return const [];

  final memoryById = {for (final m in allMemories) m.id: m};
  final ids = _memoryIdsForEntityHighlight(
    label: label,
    allMemories: allMemories,
    node: node,
    edges: edges,
  );
  if (ids.isEmpty) return const [];

  final ordered = ids.map((id) => memoryById[id]).whereType<Memory>().toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final slides = <EntityHighlightSlide>[];
  final seenPaths = <String>{};

  for (final memory in ordered) {
    final dateLabel = _formatHighlightDate(memory.createdAt, localeCode);
    final memoryTitle = _memoryTitle(memory);

    final photos = resolvedFullImagePathsForMemoryId(memory.id, imagePaths);
    final memos = photoMemosForMemoryId(
      memory.id,
      imageMemos,
      memory: memory,
      photoCount: photos.length,
    );
    for (var i = 0; i < photos.length; i++) {
      final path = photos[i];
      if (!seenPaths.add(path)) continue;
      slides.add(EntityHighlightSlide(
        imagePath: path,
        memoryId: memory.id,
        caption: i < memos.length ? memos[i] : '',
        dateLabel: dateLabel,
        memoryTitle: memoryTitle,
      ));
    }

    for (final video in resolvedVideoPathsForMemoryId(memory.id, videoPaths)) {
      if (!seenPaths.add(video)) continue;
      slides.add(EntityHighlightSlide(
        videoPath: video,
        memoryId: memory.id,
        caption: '',
        dateLabel: dateLabel,
        memoryTitle: memoryTitle,
      ));
    }
  }

  return slides;
}

int countEntityHighlightSlides({
  required String entityLabel,
  required List<Memory> allMemories,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> videoPaths,
  GraphNodeData? node,
  List<GraphEdgeData>? edges,
}) {
  return collectEntityHighlightSlides(
    entityLabel: entityLabel,
    allMemories: allMemories,
    imagePaths: imagePaths,
    imageMemos: const {},
    videoPaths: videoPaths,
    node: node,
    edges: edges,
  ).length;
}

Set<String> _memoryIdsForEntityHighlight({
  required String label,
  required List<Memory> allMemories,
  GraphNodeData? node,
  List<GraphEdgeData>? edges,
}) {
  final ids = <String>{};

  for (final memory in allMemories) {
    if (isLayoutPrimaryMemory(memory) && memoryMatchesKeyword(memory, label)) {
      ids.add(memory.id);
    }
  }

  for (final memory in allMemories) {
    final anchorId = graphNoteAnchorNodeId(memory);
    if (anchorId == null) continue;
    if (anchorId == canonicalGraphAnchorNodeId('person_$label', anchorLabel: label) ||
        anchorId == canonicalGraphAnchorNodeId('place_$label', anchorLabel: label) ||
        anchorId == canonicalGraphAnchorNodeId('activity_$label', anchorLabel: label) ||
        anchorId == canonicalGraphAnchorNodeId(label, anchorLabel: label)) {
      ids.add(memory.id);
    }
  }

  if (node != null && edges != null) {
    if (node.id.startsWith('memory_') ||
        node.id.startsWith('event_hub_') ||
        node.id.startsWith('entity_note_')) {
      final memoryId = node.id.replaceFirst(RegExp(r'^(memory_|event_hub_|entity_note_)'), '');
      ids.add(memoryId);
    } else {
      for (final memory in connectedMemoriesForNode(
        node: node,
        allMemories: allMemories,
        edges: edges,
      )) {
        if (isLayoutPrimaryMemory(memory)) ids.add(memory.id);
      }
      if (node.kind == GraphNodeKind.person ||
          node.kind == GraphNodeKind.place ||
          node.kind == GraphNodeKind.activity) {
        final anchorId = canonicalGraphAnchorNodeIdForNode(node);
        for (final memory in allMemories) {
          if (graphNoteAnchorNodeId(memory) == anchorId) ids.add(memory.id);
        }
      }
    }
  }

  return ids;
}

String _formatHighlightDate(DateTime date, String localeCode) {
  if (localeCode == 'ko') {
    return DateFormat('yyyy년 M월 d일', 'ko').format(date);
  }
  return DateFormat('MMM d, yyyy', 'en').format(date);
}

String _memoryTitle(Memory memory) {
  final summary = memory.summary.trim();
  if (summary.isNotEmpty) return summary;
  final content = memory.content.trim();
  if (content.isEmpty) return memory.id;
  final first = content.split(RegExp(r'[\n\r]+')).first.trim();
  return first.length > 40 ? '${first.substring(0, 39)}…' : first;
}
