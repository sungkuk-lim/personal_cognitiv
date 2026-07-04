import 'package:intl/intl.dart';

import '../../models/memory.dart';
import '../../utils/korean_person_names.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_id.dart';
import '../../utils/ocr_utils.dart';
import 'graph_layout.dart';

/// 관계망 AI 시트에서 저장할 때 쓰는 앵커 노드 ID (focus_hub → person 통합).
String canonicalGraphAnchorNodeId(String rawId, {String? anchorLabel}) {
  var id = rawId.trim();
  if (id.startsWith('focus_hub_')) {
    id = 'person_${id.replaceFirst('focus_hub_', '')}';
  }
  if (id.isEmpty) {
    final label = anchorLabel?.trim() ?? '';
    if (label.isNotEmpty && isLikelyKoreanPersonName(label)) {
      return 'person_$label';
    }
  }
  return id;
}

String canonicalGraphAnchorNodeIdForNode(GraphNodeData node) =>
    canonicalGraphAnchorNodeId(node.id, anchorLabel: node.title.trim());

/// 인물·장소 등 엔티티 노드에 미디어를 붙일 때 graph_note 앵커로 씁니다.
bool isEntityGraphMediaAnchor(String nodeId) {
  final id = nodeId.trim();
  if (id.isEmpty) return false;
  if (id.startsWith('memory_') ||
      id.startsWith('event_hub_') ||
      id.startsWith('entity_note_') ||
      id.startsWith('group_') ||
      id.startsWith('focus_hub_')) {
    return false;
  }
  return true;
}

String graphAnchorLabelFromNodeId(String nodeId) {
  const prefixes = ['person_', 'place_', 'organization_', 'activity_', 'goal_', 'emotion_'];
  for (final prefix in prefixes) {
    if (nodeId.startsWith(prefix)) return nodeId.substring(prefix.length);
  }
  return nodeId;
}

Memory buildMediaOnlyGraphNote({
  required String anchorNodeId,
  required String anchorLabel,
  required String localeCode,
  String? relatedMemoryId,
}) {
  final anchor = anchorLabel.trim().isNotEmpty ? anchorLabel.trim() : graphAnchorLabelFromNodeId(anchorNodeId);
  return Memory(
    id: generateMemoryId(),
    content: anchor,
    summary: '$anchor ·',
    entities: [anchor],
    createdAt: DateTime.now(),
    type: kGraphNoteMemoryType,
    category: 'Social',
    subCategory: localeCode == 'ko' ? '관계망 메모' : 'Graph note',
    isLocalOnly: true,
    userMemo: buildGraphNoteUserMemo(
      relatedMemoryId: relatedMemoryId,
      anchorNodeId: anchorNodeId,
    ),
  );
}

/// graph_related가 없을 때 인물·장소 이름으로 본 기억을 찾습니다.
Memory? inferPrimaryMemoryForGraphAnchor(String anchorLabel, List<Memory> primaryMemories) {
  final anchor = anchorLabel.trim();
  if (anchor.isEmpty) return null;

  Memory? best;
  var bestScore = 0;
  for (final memory in primaryMemories) {
    if (isGraphNoteMemory(memory)) continue;
    var score = 0;
    if (memory.entities.contains(anchor)) score += 12;
    if (memory.content.contains(anchor)) score += 6;
    if (memory.summary.contains(anchor)) score += 4;
    if (score > bestScore) {
      bestScore = score;
      best = memory;
    }
  }
  return bestScore > 0 ? best : null;
}

/// graph_related ID 또는 앵커 이름으로 연결 본문 기억을 찾습니다.
Memory? resolveGraphNoteRelatedMemory(Memory note, List<Memory> primaryMemories) {
  final relatedId = graphNoteRelatedMemoryId(note);
  if (relatedId != null) {
    for (final memory in primaryMemories) {
      if (memory.id == relatedId) return memory;
    }
  }
  final anchor = graphNoteAnchorLabel(note);
  if (anchor == null || anchor.isEmpty) return null;
  return inferPrimaryMemoryForGraphAnchor(anchor, primaryMemories);
}

/// 클라우드 동기화 등으로 type이 voice로 바뀐 관계망 메모를 복구합니다.
Memory normalizeGraphNoteMemory(Memory memory) {
  if (isGraphNoteMemory(memory)) return memory;
  if (memory.subCategory == '관계망 메모' || memory.subCategory == 'Graph note') {
    return memory.copyWith(type: kGraphNoteMemoryType);
  }
  if (memory.content.contains('— 관계망 대화') || memory.content.contains('— Graph chat')) {
    return memory.copyWith(type: kGraphNoteMemoryType);
  }
  if (isGraphAnchorMediaStorage(memory)) {
    return memory.copyWith(type: kGraphNoteMemoryType);
  }
  return memory;
}

/// 관계망 AI 대화에서 만든 경량 기억 조각.
const String kGraphNoteMemoryType = 'graph_note';
const String kGraphRelatedMemoPrefix = 'graph_related:';
const String kGraphAnchorMemoPrefix = 'graph_anchor:';

enum GraphChatSaveKind {
  /// 인물·장소·조직 노드 — 새 기억 조각 생성.
  entityAnchor,
  /// 이벤트·기억 노드 — 기존 본문 맨 아래 붙이기.
  eventAppend,
}

class GraphChatSaveResult {
  const GraphChatSaveResult({
    required this.memory,
    required this.kind,
    required this.anchorLabel,
    this.relatedEventLabel,
    required this.isNewMemory,
  });

  final Memory memory;
  final GraphChatSaveKind kind;
  final String anchorLabel;
  final String? relatedEventLabel;
  final bool isNewMemory;
}

GraphChatSaveKind resolveGraphChatSaveKind(GraphNodeData node) {
  if (node.id.startsWith('memory_') ||
      node.id.startsWith('event_hub_') ||
      node.kind == GraphNodeKind.group ||
      node.kind == GraphNodeKind.memory) {
    return GraphChatSaveKind.eventAppend;
  }
  if (node.kind == GraphNodeKind.person ||
      node.kind == GraphNodeKind.place ||
      node.kind == GraphNodeKind.goal) {
    return GraphChatSaveKind.entityAnchor;
  }
  if (node.kind == GraphNodeKind.activity || node.kind == GraphNodeKind.emotion) {
    return GraphChatSaveKind.entityAnchor;
  }
  return GraphChatSaveKind.eventAppend;
}

bool graphChatSaveNeedsLinkedMemories(GraphNodeData node) =>
    resolveGraphChatSaveKind(node) == GraphChatSaveKind.eventAppend;

/// 노드 종류에 따라 저장 계획을 만듭니다.
GraphChatSaveResult? planGraphChatSave({
  required GraphNodeData node,
  required List<String> userLines,
  required List<Memory> contextMemories,
  required List<Memory> allMemories,
  required String localeCode,
  required String markerLabel,
}) {
  if (userLines.isEmpty) return null;

  final kind = resolveGraphChatSaveKind(node);
  if (kind == GraphChatSaveKind.entityAnchor) {
    final anchorId = canonicalGraphAnchorNodeIdForNode(node);
    final existing = findGraphAnchorMemory(allMemories, anchorId);
    if (existing != null) {
      return GraphChatSaveResult(
        memory: appendEntityAnchorGraphNote(
          existing: existing,
          userLines: userLines,
          localeCode: localeCode,
          markerLabel: markerLabel,
        ),
        kind: kind,
        anchorLabel: node.title.trim(),
        relatedEventLabel: _relatedEventLabel(contextMemories),
        isNewMemory: false,
      );
    }
    return GraphChatSaveResult(
      memory: buildEntityAnchorGraphNote(
        node: node,
        userLines: userLines,
        contextMemories: contextMemories,
        localeCode: localeCode,
        markerLabel: markerLabel,
      ),
      kind: kind,
      anchorLabel: node.title.trim(),
      relatedEventLabel: _relatedEventLabel(contextMemories),
      isNewMemory: true,
    );
  }

  if (contextMemories.isEmpty) return null;
  final target = contextMemories.first;
  return GraphChatSaveResult(
    memory: applyGraphChatAppend(
      memory: target,
      userLines: userLines,
      localeCode: localeCode,
      markerLabel: markerLabel,
    ),
    kind: kind,
    anchorLabel: _memoryDisplayTitle(target),
    relatedEventLabel: null,
    isNewMemory: false,
  );
}

Memory appendEntityAnchorGraphNote({
  required Memory existing,
  required List<String> userLines,
  required String localeCode,
  required String markerLabel,
}) {
  final anchor = graphNoteAnchorLabel(existing) ?? existing.entities.firstOrNull ?? '';
  final userBlock = userLines.join('\n');
  final stamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  final addition = _entityNoteContent(
    anchorLabel: anchor,
    userBlock: userBlock,
    markerLabel: markerLabel,
    stamp: stamp,
    localeCode: localeCode,
  );
  final mergedContent = '${existing.content.trim()}\n\n$addition'.trim();
  final summary = _entityNoteSummary(anchor: anchor, userBlock: userBlock, localeCode: localeCode);
  return existing.copyWith(
    content: mergedContent,
    summary: summary,
    createdAt: DateTime.now(),
  );
}

Memory buildEntityAnchorGraphNote({
  required GraphNodeData node,
  required List<String> userLines,
  required List<Memory> contextMemories,
  required String localeCode,
  required String markerLabel,
}) {
  final anchor = node.title.trim();
  final userBlock = userLines.join('\n');
  final stamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  final content = _entityNoteContent(
    anchorLabel: anchor,
    userBlock: userBlock,
    markerLabel: markerLabel,
    stamp: stamp,
    localeCode: localeCode,
  );

  final summary = _entityNoteSummary(anchor: anchor, userBlock: userBlock, localeCode: localeCode);
  final context = contextMemories.isNotEmpty ? contextMemories.first : null;
  final relatedMemo = buildGraphNoteUserMemo(
    relatedMemoryId: context?.id,
    anchorNodeId: canonicalGraphAnchorNodeIdForNode(node),
  );

  final draft = Memory(
    id: generateMemoryId(),
    content: content,
    summary: summary,
    entities: [anchor],
    createdAt: context?.createdAt ?? DateTime.now(),
    type: kGraphNoteMemoryType,
    category: 'Social',
    subCategory: localeCode == 'ko' ? '관계망 메모' : 'Graph note',
    lat: context?.lat,
    lng: context?.lng,
    isLocalOnly: true,
    userMemo: relatedMemo,
  );

  final bundle = extractMemoryEntities(draft, localeCode: localeCode);
  final entities = <String>[];
  final seen = <String>{};
  void addEntity(String raw) {
    final value = raw.trim();
    if (value.isEmpty || !seen.add(value)) return;
    if (isInternalMemoryEntityTag(value)) return;
    if (!shouldShowGraphSatelliteLabel(value)) return;
    entities.add(value);
  }

  addEntity(anchor);
  for (final p in bundle.places) {
    addEntity(p);
  }
  for (final o in bundle.organizations) {
    addEntity(o);
  }

  return draft.copyWith(entities: entities.take(kGraphMaxPeopleSatellites + 3).toList());
}

Memory applyGraphChatAppend({
  required Memory memory,
  required List<String> userLines,
  required String localeCode,
  required String markerLabel,
}) {
  final block = userLines.join('\n');
  final stamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
  final appendix = '\n\n— $markerLabel ($stamp) —\n$block';
  final content = '${memory.content}$appendix';
  final draft = memory.copyWith(content: content);
  final bundle = extractMemoryEntities(draft, localeCode: localeCode);

  final seen = <String>{};
  final entities = <String>[];
  void addEntity(String raw) {
    final value = raw.trim();
    if (value.isEmpty || !seen.add(value)) return;
    if (isInternalMemoryEntityTag(value)) return;
    if (!shouldShowGraphSatelliteLabel(value)) return;
    entities.add(value);
  }

  for (final e in memory.entities) {
    addEntity(e);
  }
  for (final p in bundle.people) {
    addEntity(p);
  }
  for (final p in bundle.places) {
    addEntity(p);
  }
  for (final o in bundle.organizations) {
    addEntity(o);
  }

  return draft.copyWith(entities: entities.take(kGraphMaxPeopleSatellites + 3).toList());
}

bool isGraphNoteMemory(Memory memory) => memory.type == kGraphNoteMemoryType;

/// 관계망 허브 카드로 올리면 안 되는 내부 메모·관계망 전용 기억.
bool isLayoutPrimaryMemory(Memory memory) {
  if (isGraphNoteMemory(memory)) return false;
  final sub = memory.subCategory.trim();
  if (sub == '관계망 메모' || sub == 'Graph note') return false;
  if (memory.userMemo.contains(kGraphAnchorMemoPrefix)) return false;
  return true;
}

/// 앵커 노드에 연결된 graph_note 기억을 찾습니다.
Memory? findGraphAnchorMemory(List<Memory> memories, String anchorNodeId) {
  final anchorId = canonicalGraphAnchorNodeId(anchorNodeId);
  for (final memory in memories) {
    if (graphNoteAnchorNodeId(memory) == anchorId) return memory;
  }
  return null;
}

/// 인물·장소·활동 노드 미디어 저장소 — 타임라인·회상에 노출하지 않습니다.
bool isGraphAnchorMediaStorage(Memory memory) {
  final anchorId = graphNoteAnchorNodeId(memory);
  if (anchorId == null || anchorId.isEmpty) return false;
  return graphNoteFactTitle(memory).trim().isEmpty;
}

/// 타임라인·회상·검색에 보여줄 사용자 기억인지.
bool isUserFacingMemory(Memory memory) => !isGraphAnchorMediaStorage(memory);

class MemoryBodyDisplayParts {
  const MemoryBodyDisplayParts({
    required this.mainText,
    this.appendixText,
    required this.isEntityNote,
  });

  final String mainText;
  final String? appendixText;
  final bool isEntityNote;
}

MemoryBodyDisplayParts splitMemoryBodyForDisplay(Memory memory, {required String graphMarkerLabel}) {
  final raw = memory.content.trim();
  if (raw.isEmpty) {
    return const MemoryBodyDisplayParts(mainText: '', isEntityNote: false);
  }
  if (isGraphNoteMemory(memory)) {
    final fact = graphNoteFactTitle(memory);
    return MemoryBodyDisplayParts(mainText: fact, isEntityNote: true);
  }

  final marker = '— $graphMarkerLabel';
  final idx = raw.lastIndexOf(marker);
  if (idx < 0) {
    return MemoryBodyDisplayParts(mainText: raw, isEntityNote: false);
  }

  final main = raw.substring(0, idx).trim();
  final appendix = raw.substring(idx).trim();
  if (appendix.isEmpty) {
    return MemoryBodyDisplayParts(mainText: raw, isEntityNote: false);
  }
  return MemoryBodyDisplayParts(mainText: main, appendixText: appendix, isEntityNote: false);
}

String buildGraphNoteUserMemo({String? relatedMemoryId, required String anchorNodeId}) {
  final parts = <String>[];
  final related = relatedMemoryId?.trim();
  if (related != null && related.isNotEmpty) {
    parts.add('$kGraphRelatedMemoPrefix$related');
  }
  final anchor = anchorNodeId.trim();
  if (anchor.isNotEmpty) {
    parts.add('$kGraphAnchorMemoPrefix$anchor');
  }
  return parts.join('|');
}

/// UI에 노출하면 안 되는 관계망 내부 메모(graph_related·graph_anchor)인지 확인합니다.
bool isInternalGraphNoteUserMemo(String memo) {
  final value = memo.trim();
  if (value.isEmpty) return false;
  return value.contains(kGraphRelatedMemoPrefix) || value.contains(kGraphAnchorMemoPrefix);
}

/// 타임라인·상세에 쓸 사용자 메모 — 관계망 내부 메타데이터는 제외합니다.
String displayUserMemoForMemory(Memory memory) {
  if (isGraphNoteMemory(memory)) return '';
  final memo = memory.userMemo.trim();
  if (isInternalGraphNoteUserMemo(memo)) return '';
  return memo;
}

String? graphNoteRelatedMemoryId(Memory memory) {
  final memo = memory.userMemo.trim();
  final match = RegExp(r'graph_related:([^\s|]+)').firstMatch(memo);
  final id = match?.group(1)?.trim();
  return id == null || id.isEmpty ? null : id;
}

String? graphNoteAnchorNodeId(Memory memory) {
  final memo = memory.userMemo.trim();
  final match = RegExp(r'graph_anchor:([^\s|]+)').firstMatch(memo);
  final id = match?.group(1)?.trim();
  return id == null || id.isEmpty ? null : id;
}

bool isMediaOnlyGraphNote(Memory memory) => isGraphAnchorMediaStorage(memory) && isGraphNoteMemory(memory);

String graphNoteFactTitle(Memory memory) {
  final anchor = graphNoteAnchorLabel(memory)?.trim();
  final summary = memory.summary.trim();
  var fact = '';
  if (summary.contains('·')) {
    fact = summary.split('·').skip(1).join('·').trim();
  }
  if (fact.isEmpty) {
    final main = memory.content.split(RegExp(r'\n\n— ')).first.trim();
    final dash = main.indexOf(' — ');
    if (dash >= 0) {
      fact = main.substring(dash + 3).trim();
    }
  }
  if (anchor != null && fact == anchor) return '';
  final content = memory.content.trim();
  if (fact.isEmpty && anchor != null && content == anchor) return '';
  return fact;
}

/// 타임라인·상세 본문 — 앵커 인물명은 배너에만 표시하고 사실만 노출합니다.
String graphNoteCardBody(Memory memory) => graphNoteDetailBody(memory);

String graphNoteDetailBody(Memory memory) {
  final fact = graphNoteFactTitle(memory);
  final anchor = graphNoteAnchorLabel(memory)?.trim();
  if (fact.isEmpty) return '';
  if (anchor != null && (fact == anchor || fact.startsWith('$anchor ·'))) return '';
  return fact;
}

bool isGraphNotePlaceUnknown(String placeTitle, String localeCode) =>
    placeTitle == (localeCode == 'ko' ? '장소 미상' : 'Unknown place');

/// 같은 사실 문구가 여러 인물에 붙으면 노드 제목에 인물명을 넣습니다.
String graphNoteNodeTitle(Memory note, List<Memory> allGraphNotes) {
  final fact = graphNoteFactTitle(note);
  final anchor = graphNoteAnchorLabel(note);
  if (anchor == null || anchor.isEmpty) return fact;
  final hasDuplicateFact = allGraphNotes.any(
    (other) => other.id != note.id && graphNoteFactTitle(other) == fact,
  );
  if (hasDuplicateFact) return '$anchor · $fact';
  return fact;
}

String graphNoteAnchorEntityPrefix(Memory memory) {
  final anchor = graphNoteAnchorLabel(memory) ?? memory.entities.firstOrNull ?? '';
  if (anchor.isEmpty) return 'person';
  if (isLikelyKoreanPersonName(anchor)) return 'person';
  if (looksLikeKoreanPlaceName(anchor) || RegExp(r'(?:요리집|식당|병원|해수욕장)$').hasMatch(anchor)) {
    return 'place';
  }
  return 'organization';
}

String? graphNoteAnchorLabel(Memory memory) {
  final anchorNodeId = graphNoteAnchorNodeId(memory);
  if (anchorNodeId != null) {
    final fromId = graphAnchorLabelFromNodeId(anchorNodeId).trim();
    if (fromId.isNotEmpty) return fromId;
  }
  if (!isGraphNoteMemory(memory)) return null;
  final summary = memory.summary.trim();
  if (summary.contains('·')) {
    return summary.split('·').first.trim();
  }
  final head = memory.content.split('—').first.trim();
  if (head.contains(' — ')) {
    return head.split(' — ').first.trim();
  }
  return memory.entities.isNotEmpty ? memory.entities.first : null;
}

String _entityNoteContent({
  required String anchorLabel,
  required String userBlock,
  required String markerLabel,
  required String stamp,
  required String localeCode,
}) {
  return '$anchorLabel — $userBlock\n\n— $markerLabel ($stamp) —';
}

String _entityNoteSummary({
  required String anchor,
  required String userBlock,
  required String localeCode,
}) {
  final firstLine = userBlock.split(RegExp(r'[\n\r]+')).first.trim();
  final tail = firstLine.length > 36 ? '${firstLine.substring(0, 35)}…' : firstLine;
  return '$anchor · $tail';
}

String? _relatedEventLabel(List<Memory> contextMemories) {
  if (contextMemories.isEmpty) return null;
  final memory = contextMemories.first;
  final summary = memory.summary.trim();
  if (summary.isNotEmpty) return summary;
  final event = extractEventTitleFromText(memory.content);
  if (event.isNotEmpty) return event;
  return _memoryDisplayTitle(memory);
}

String _memoryDisplayTitle(Memory memory) {
  final summary = memory.summary.trim();
  if (summary.isNotEmpty) {
    return summary.length > 28 ? '${summary.substring(0, 27)}…' : summary;
  }
  final content = memory.content.trim();
  if (content.isEmpty) return memory.id;
  final firstLine = content.split(RegExp(r'[\n\r]+')).first.trim();
  return firstLine.length > 28 ? '${firstLine.substring(0, 27)}…' : firstLine;
}
