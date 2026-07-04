import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import '../../utils/embedding_utils.dart';
import '../../utils/graph_fragment_freshness.dart';
import '../../utils/graph_meaning.dart';
import '../../utils/graph_memory_card_labels.dart';
import '../../core/app_theme.dart';
import '../../core/graph_scale_config.dart';
import '../../utils/graph_entity_context.dart';
import '../../utils/graph_satellites.dart';
import '../../utils/memory_grouping.dart';
import '../../utils/ocr_utils.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../utils/korean_person_names.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_participation_extract.dart';
import '../../utils/entity_canonical.dart';
import '../../utils/memory_graph_semantics.dart';
import 'graph_chat_save.dart';

/// 관계망 노드 종류 — 기억·이벤트 허브, 위성은 사람·장소·활동·목표·감정.
enum GraphNodeKind { memory, group, eventHub, person, place, activity, goal, emotion }

/// 위성 펼침 필터 — 사람·장소만 또는 전체.
enum GraphSatelliteExpandMode { person, place, personAndPlace, all }

class GraphNodeData {
  final String id;
  final String title;
  final String subtitle;
  final String dateLabel;
  final String placeLabel;
  final Color color;
  final GraphNodeKind kind;
  final Size size;
  /// 배치·드래그 묶음 (같은 날+장소 타임라인 그룹).
  final String layoutClusterId;
  /// 위성 접힘 시 배지 (예: 👤2 · 📍1).
  final String? satelliteBadge;

  const GraphNodeData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.dateLabel = '',
    this.placeLabel = '',
    required this.color,
    required this.kind,
    required this.size,
    required this.layoutClusterId,
    this.satelliteBadge,
  });

  bool get isMemory => kind == GraphNodeKind.memory || kind == GraphNodeKind.group;
  bool get isPrimaryCard => kind == GraphNodeKind.memory || kind == GraphNodeKind.group;
  bool get isDraggablePrimary => kind == GraphNodeKind.memory || kind == GraphNodeKind.group;
}

/// 위성·엔티티 노드 종류별 색 — 한눈에 구분.
Color graphNodeKindColor(GraphNodeKind kind) {
  return switch (kind) {
    GraphNodeKind.person => AppGraphColors.person,
    GraphNodeKind.place => AppGraphColors.place,
    GraphNodeKind.activity => AppGraphColors.activity,
    GraphNodeKind.goal => AppGraphColors.memory,
    GraphNodeKind.emotion => const Color(0xFFFF7043),
    GraphNodeKind.eventHub => AppGraphColors.eventHub,
    GraphNodeKind.memory => AppGraphColors.memory,
    GraphNodeKind.group => AppGraphColors.group,
  };
}

class GraphEdgeData {
  final String fromId;
  final String toId;
  final Color color;
  final bool memoryToMemory;
  final bool semanticLink;
  /// 서로 다른 허브(묶음)를 잇는 공유 엔티티 브리지.
  final bool bridgeLink;
  /// 관계 라벨 (동행·방문·식사 등).
  final String? label;
  final bool relationEdge;

  const GraphEdgeData({
    required this.fromId,
    required this.toId,
    required this.color,
    this.memoryToMemory = false,
    this.semanticLink = false,
    this.bridgeLink = false,
    this.label,
    this.relationEdge = false,
  });
}

class GraphLayout {
  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;

  const GraphLayout({required this.nodes, required this.edges});
}

class KeywordFocusGraphResult {
  const KeywordFocusGraphResult({
    required this.layout,
    required this.totalCount,
    required this.shownCount,
  });

  final GraphLayout layout;
  final int totalCount;
  final int shownCount;

  int get hiddenCount => totalCount - shownCount;
}

int _defaultPhotoCount(String memoryId) => 0;
bool _defaultHasVideo(String memoryId) => false;

const int kGraphMaxSemanticLinksPerMemory = 3;

GraphLayout buildMemoryGraphLayout(
  List<Memory> memories, {
  Map<String, String> placeCache = const {},
  Map<String, String> fullAddressCache = const {},
  Map<String, GraphMemoryFragment> graphFragments = const {},
  Map<String, GraphClusterSnapshot> graphClusters = const {},
  String localeCode = 'ko',
  int Function(String memoryId) photoCountFor = _defaultPhotoCount,
  bool Function(String memoryId) hasVideoFor = _defaultHasVideo,
  Map<String, GraphSatelliteExpandMode> satelliteExpansions = const {},
  bool collapseSatellitesByDefault = true,
  int maxSemanticLinksPerMemory = kGraphMaxSemanticLinksPerMemory,
}) {
  final nodes = <GraphNodeData>[];
  final edges = <GraphEdgeData>[];
  final globalEntityIds = <String, String>{};
  final claimedSatelliteLabels = <String, String>{};
  final remappedLayoutIds = <String, String>{};
  final graphNodeIds = <String>{};
  final entityTitleToNodeId = <String, String>{};

  GraphMemoryFragment? fragmentFor(Memory memory) =>
      freshGraphFragmentForMemory(memory, graphFragments[memory.id]);

  String globalEntityId(String prefix, String label) {
    return globalEntityIds.putIfAbsent('$prefix::$label', () => '${prefix}_$label');
  }

  void addNode(GraphNodeData node) {
    if (node.kind == GraphNodeKind.person ||
        node.kind == GraphNodeKind.place ||
        node.kind == GraphNodeKind.activity) {
      final dedupeKey = '${node.kind.name}::${node.title.trim()}';
      final existingId = entityTitleToNodeId[dedupeKey];
      if (existingId != null && existingId != node.id) {
        remappedLayoutIds[node.id] = existingId;
        graphNodeIds.add(existingId);
        return;
      }
      entityTitleToNodeId[dedupeKey] = node.id;
    }
    final idx = nodes.indexWhere((n) => n.id == node.id);
    if (idx >= 0) {
      nodes[idx] = node;
      graphNodeIds.add(node.id);
      return;
    }
    nodes.add(node);
    graphNodeIds.add(node.id);
  }

  void link(
    String from,
    String to,
    Color color, {
    bool memoryToMemory = false,
    bool semantic = false,
    bool bridge = false,
    String? label,
    bool relationEdge = false,
  }) {
    from = remappedLayoutIds[from] ?? from;
    to = remappedLayoutIds[to] ?? to;
    if (from == to) return;
    final exists = edges.any(
      (e) =>
          (e.fromId == from && e.toId == to) ||
          (e.fromId == to && e.toId == from &&
              e.memoryToMemory == memoryToMemory &&
              e.bridgeLink == bridge),
    );
    if (exists) return;
    edges.add(GraphEdgeData(
      fromId: from,
      toId: to,
      color: color,
      memoryToMemory: memoryToMemory,
      semanticLink: semantic,
      bridgeLink: bridge,
      label: label,
      relationEdge: relationEdge,
    ));
  }

  final graphNotes = memories
      .where((m) => isGraphNoteMemory(m) || graphNoteAnchorNodeId(m) != null)
      .toList();
  final rawTimelineGroups = groupMemoriesForTimeline(memories);

  for (final rawGroup in rawTimelineGroups) {
    final primaryMemories = rawGroup.memories.where(isLayoutPrimaryMemory).toList();
    if (primaryMemories.isEmpty) continue;

    final clusterId = rawGroup.key.id;
    final clusterColor = colorForMemoryCluster(rawGroup.key);
    final groupHubId = 'group_$clusterId';
    final showDayHub = primaryMemories.length > 1;
    final labelGroup = MemoryTimelineGroup(key: rawGroup.key, memories: primaryMemories);
    final suppressedMemoryIds = <String>{};
    var hubTitle = '';

    if (showDayHub) {
      final hubLabels = buildGroupGraphCardLabels(
        labelGroup,
        placeCache,
        fullAddressCache,
        localeCode: localeCode,
      );
      final clusterAi = graphClusters[clusterId];
      hubTitle = clusterAi != null &&
              clusterAi.isUsable &&
              !isGraphClusterSnapshotStale(labelGroup, clusterAi, localeCode: localeCode)
          ? clusterAi.clusterTitle
          : hubLabels.meaningLine;
      addNode(GraphNodeData(
        id: groupHubId,
        title: hubTitle,
        subtitle: _nodeCardSubtitle(GraphNodeKind.group, localeCode),
        dateLabel: hubLabels.metaLine,
        placeLabel: hubLabels.addressLine,
        color: clusterColor,
        kind: GraphNodeKind.group,
        size: const Size(204, 124),
        layoutClusterId: clusterId,
      ));

      for (final memory in primaryMemories) {
        final fragment = fragmentFor(memory);
        final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: fragment);
        final cardLabels = buildGraphMemoryCardLabels(
          memory,
          placeCache,
          fullAddressCache,
          localeCode: localeCode,
        );
        final meaningTitle = bundle.eventTitle.isNotEmpty ? bundle.eventTitle : cardLabels.meaningLine;
        if (_graphTitlesOverlap(meaningTitle, hubTitle)) {
          suppressedMemoryIds.add(memory.id);
          remappedLayoutIds['memory_${memory.id}'] = groupHubId;
        }
      }
    }

    for (final memory in primaryMemories) {
      final suppressed = suppressedMemoryIds.contains(memory.id);
      final memoryId = 'memory_${memory.id}';
      final fragment = fragmentFor(memory);
      final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: fragment);
      final cardLabels = buildGraphMemoryCardLabels(
        memory,
        placeCache,
        fullAddressCache,
        localeCode: localeCode,
      );
      final meaningTitle = bundle.eventTitle.isNotEmpty ? bundle.eventTitle : cardLabels.meaningLine;

      if (!suppressed) {
        addNode(GraphNodeData(
          id: memoryId,
          title: meaningTitle,
          subtitle: _nodeCardSubtitle(GraphNodeKind.memory, localeCode),
          dateLabel: cardLabels.metaLine,
          placeLabel: cardLabels.addressLine,
          color: clusterColor,
          kind: GraphNodeKind.memory,
          size: const Size(204, 124),
          layoutClusterId: clusterId,
          satelliteBadge: GraphEntityContext.forMemory(
            memory,
            localeCode: localeCode,
            aiFragment: fragment,
          ).badgeText,
        ));

        if (showDayHub) {
          link(groupHubId, memoryId, clusterColor);
        }
      }

      final expanded = satelliteExpansions.containsKey(memory.id);
      final showSatellites = !collapseSatellitesByDefault || expanded;
      if (showSatellites) {
        _attachSatelliteNodes(
          anchorNodeId: suppressed && showDayHub ? groupHubId : memoryId,
          memory: memory,
          fragment: fragment,
          clusterId: clusterId,
          clusterColor: clusterColor,
          localeCode: localeCode,
          eventTitle: bundle.eventTitle,
          claimedLabels: claimedSatelliteLabels,
          graphNodeIds: graphNodeIds,
          addNode: addNode,
          link: link,
          globalEntityId: globalEntityId,
          filterMode: expanded ? satelliteExpansions[memory.id]! : GraphSatelliteExpandMode.all,
        );
      }
    }
  }

  final layoutNodeIds = nodes.map((n) => n.id).toSet();
  final memoryById = {for (final m in memories) m.id: m};
  for (final memory in memories) {
    if (!isLayoutPrimaryMemory(memory)) continue;
    final fragment = fragmentFor(memory);
    if (fragment == null || fragment.relations.isEmpty) continue;
    final memoryId = 'memory_${memory.id}';
    final resolvedFrom = remappedLayoutIds[memoryId] ?? memoryId;
    final clusterColor = colorForMemoryCluster(clusterKeyForMemory(memory));
    for (final rel in fragment.relations) {
      final targetId = 'memory_${rel.targetMemoryId}';
      final resolvedTo = remappedLayoutIds[targetId] ?? targetId;
      final target = memoryById[rel.targetMemoryId];
      if (target == null || !layoutNodeIds.contains(resolvedFrom) || !layoutNodeIds.contains(resolvedTo)) {
        continue;
      }
      if (!_memoriesSharePeople(memory, target, localeCode: localeCode)) continue;
      link(memoryId, targetId, clusterColor, memoryToMemory: true, semantic: true);
    }
  }

  for (var i = 0; i < memories.length; i++) {
    for (var j = i + 1; j < memories.length; j++) {
      if (!isLayoutPrimaryMemory(memories[i]) || !isLayoutPrimaryMemory(memories[j])) continue;
      _maybeLinkMemoryPair(edges, memories[i], memories[j], localeCode: localeCode);
    }
  }

  final hubNodeIds = nodes.map((n) => n.id).toSet();
  for (var i = 0; i < memories.length; i++) {
    for (var j = i + 1; j < memories.length; j++) {
      final a = memories[i];
      final b = memories[j];
      if (!isLayoutPrimaryMemory(a) || !isLayoutPrimaryMemory(b)) continue;
      if (clusterKeyForMemory(a) == clusterKeyForMemory(b)) continue;
      if (!embeddingsAreSimilar(a.embedding, b.embedding)) continue;
      final fromId = 'memory_${a.id}';
      final toId = 'memory_${b.id}';
      final resolvedFrom = remappedLayoutIds[fromId] ?? fromId;
      final resolvedTo = remappedLayoutIds[toId] ?? toId;
      if (!hubNodeIds.contains(resolvedFrom) || !hubNodeIds.contains(resolvedTo)) continue;
      link(
        fromId,
        toId,
        Color.lerp(colorForMemory(a), colorForMemory(b), 0.5) ?? colorForMemory(a),
        memoryToMemory: true,
        semantic: true,
      );
    }
  }

  _attachGraphNotesToAnchors(
    graphNotes: graphNotes,
    primaryMemories: memories.where(isLayoutPrimaryMemory).toList(),
    localeCode: localeCode,
    globalEntityId: globalEntityId,
    nodeIds: nodes.map((n) => n.id).toSet(),
    addNode: addNode,
    link: link,
    graphFragments: graphFragments,
  );

  _pruneSemanticMemoryLinks(edges, maxPerMemory: maxSemanticLinksPerMemory);
  _addCrossClusterHubBridges(
    timelineGroups: rawTimelineGroups,
    graphFragments: graphFragments,
    localeCode: localeCode,
    link: link,
  );
  _addSharedEntityMemoryBridges(
    memories: memories.where(isLayoutPrimaryMemory).toList(),
    graphFragments: graphFragments,
    localeCode: localeCode,
    link: (from, to, color, {label, relationEdge = false}) =>
        link(from, to, color, memoryToMemory: true, bridge: true, label: label, relationEdge: relationEdge),
  );

  _pruneOrphanEntityNodes(nodes, edges);

  return GraphLayout(nodes: nodes, edges: edges);
}

/// 키워드 포커스 모드 — 허브 + 연결 기억 + 공통 위성(인물·장소).
KeywordFocusGraphResult buildKeywordFocusGraphLayout(
  String keyword,
  List<Memory> allMemories, {
  Map<String, String> placeCache = const {},
  Map<String, String> fullAddressCache = const {},
  Map<String, GraphMemoryFragment> graphFragments = const {},
  String localeCode = 'ko',
  int maxMemories = 12,
}) {
  final k = keyword.trim();
  final matching = allMemories
      .where(isLayoutPrimaryMemory)
      .where((m) => memoryMatchesKeyword(m, k))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final total = matching.length;
  final shown = matching.take(maxMemories).toList();

  final hubKind = shown.isEmpty
      ? GraphNodeKind.activity
      : switch (classifyKeyword(k, shown.first, localeCode: localeCode)) {
          MemoryKeywordKind.person => GraphNodeKind.person,
          MemoryKeywordKind.place => GraphNodeKind.place,
          MemoryKeywordKind.tag => GraphNodeKind.activity,
        };
  final hubColor = switch (hubKind) {
    GraphNodeKind.person => Colors.pink.shade400,
    GraphNodeKind.place => Colors.teal.shade500,
    _ => const Color(0xFF6750A4),
  };
  const clusterId = 'keyword_focus';
  final hubId = 'focus_hub_$k';
  final hubSubtitle = switch (hubKind) {
    GraphNodeKind.person || GraphNodeKind.place => '',
    _ => _kindLabel(hubKind, localeCode),
  };

  final nodes = <GraphNodeData>[
    GraphNodeData(
      id: hubId,
      title: k,
      subtitle: hubSubtitle,
      color: hubColor,
      kind: hubKind,
      size: const Size(148, 72),
      layoutClusterId: clusterId,
    ),
  ];
  final edges = <GraphEdgeData>[];
  final graphNodeIds = nodes.map((n) => n.id).toSet();
  final claimedLabels = <String, String>{};
  final globalEntityIds = <String, String>{};

  String globalEntityId(String prefix, String label) {
    return globalEntityIds.putIfAbsent('$prefix::$label', () => '${prefix}_$label');
  }

  void addNode(GraphNodeData node) {
    nodes.add(node);
    graphNodeIds.add(node.id);
  }

  void link(String from, String to, Color color, {String? label, bool relationEdge = false}) {
    edges.add(GraphEdgeData(fromId: from, toId: to, color: color, label: label, relationEdge: relationEdge));
  }

  for (final memory in shown) {
    final memoryId = 'memory_${memory.id}';
    final cardLabels = buildGraphMemoryCardLabels(
      memory,
      placeCache,
      fullAddressCache,
      localeCode: localeCode,
    );
    final fragment = freshGraphFragmentForMemory(memory, graphFragments[memory.id]);
    final title = graphMeaningSentence(memory, localeCode: localeCode);

    addNode(GraphNodeData(
      id: memoryId,
      title: title,
      subtitle: _nodeCardSubtitle(GraphNodeKind.memory, localeCode),
      dateLabel: cardLabels.metaLine,
      placeLabel: cardLabels.addressLine,
      color: hubColor.withValues(alpha: 0.85),
      kind: GraphNodeKind.memory,
      size: const Size(204, 124),
      layoutClusterId: clusterId,
    ));
    link(hubId, memoryId, hubColor.withValues(alpha: 0.7));

    _attachSatelliteNodes(
      anchorNodeId: hubId,
      memory: memory,
      fragment: fragment,
      clusterId: clusterId,
      clusterColor: hubColor,
      localeCode: localeCode,
      eventTitle: k,
      claimedLabels: claimedLabels,
      graphNodeIds: graphNodeIds,
      addNode: addNode,
      link: link,
      globalEntityId: globalEntityId,
      filterMode: GraphSatelliteExpandMode.all,
    );
  }

  return KeywordFocusGraphResult(
    layout: GraphLayout(nodes: nodes, edges: edges),
    totalCount: total,
    shownCount: shown.length,
  );
}

Map<String, Offset> initialKeywordFocusPositions(List<GraphNodeData> nodes, Size canvasSize) {
  final positions = <String, Offset>{};
  if (nodes.isEmpty) return positions;

  final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
  final hub = nodes.firstWhere((n) => n.id.startsWith('focus_hub_'), orElse: () => nodes.first);
  positions[hub.id] = center;

  final memories = nodes.where((n) => n.kind == GraphNodeKind.memory).toList();
  if (memories.isEmpty) return positions;

  final radius = memories.length <= 4
      ? 220.0
      : memories.length <= 8
          ? 280.0
          : 340.0;

  for (var i = 0; i < memories.length; i++) {
    final angle = (2 * math.pi * i / memories.length) - math.pi / 2;
    positions[memories[i].id] = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  final satellites = nodes
      .where((n) => n.kind != GraphNodeKind.memory && !n.id.startsWith('focus_hub_'))
      .toList();
  for (var i = 0; i < satellites.length; i++) {
    final angle = (2 * math.pi * i / math.max(satellites.length, 1)) + math.pi / 6;
    positions[satellites[i].id] = center + Offset(math.cos(angle) * 130, math.sin(angle) * 100);
  }
  return positions;
}

Size keywordFocusCanvasSize(int memoryCount) {
  if (memoryCount <= 4) return const Size(1100, 900);
  if (memoryCount <= 8) return const Size(1300, 1000);
  return const Size(1500, 1100);
}

bool _graphTitlesOverlap(String a, String b) {
  final x = a.trim();
  final y = b.trim();
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  return x.contains(y) || y.contains(x);
}

void _attachSatelliteNodes({
  required String anchorNodeId,
  required Memory memory,
  GraphMemoryFragment? fragment,
  required String clusterId,
  required Color clusterColor,
  required String localeCode,
  String eventTitle = '',
  required Map<String, String> claimedLabels,
  required Set<String> graphNodeIds,
  required void Function(GraphNodeData node) addNode,
  required void Function(String from, String to, Color color, {String? label, bool relationEdge}) link,
  required String Function(String prefix, String label) globalEntityId,
  GraphSatelliteExpandMode filterMode = GraphSatelliteExpandMode.all,
}) {
  final satellites = visibleGraphSatellitesForMemory(
    memory,
    localeCode: localeCode,
    aiFragment: fragment,
    hubTitle: eventTitle,
  );
  final people = satellites.people;

  void attachMany(String kindPrefix, GraphNodeKind kind, List<String> labels, {required int max}) {
    if (!_satelliteKindAllowed(kindPrefix, filterMode)) return;
    for (final label in labels.take(max)) {
      final id = globalEntityId(kindPrefix, label);
      if (!graphNodeIds.contains(id)) {
        if (shouldClaimSatelliteLabel(claimedLabels, label, kindPrefix)) {
          claimSatelliteLabel(claimedLabels, label, kindPrefix);
        }
        addNode(GraphNodeData(
          id: id,
          title: label,
          subtitle: _nodeCardSubtitle(kind, localeCode),
          color: graphNodeKindColor(kind),
          kind: kind,
          size: const Size(112, 48),
          layoutClusterId: clusterId,
        ));
        graphNodeIds.add(id);
      }
      link(anchorNodeId, id, clusterColor);
    }
  }

  attachMany(
    'person',
    GraphNodeKind.person,
    people,
    max: kGraphMaxPeopleSatellites,
  );
  attachMany('place', GraphNodeKind.place, satellites.places, max: kGraphMaxPlaceSatellites);
  attachMany('organization', GraphNodeKind.goal, satellites.organizations, max: kGraphMaxOrgSatellites);
  attachMany('activity', GraphNodeKind.activity, satellites.activities, max: 2);
  attachMany('goal', GraphNodeKind.goal, satellites.goals, max: 1);
  attachMany('emotion', GraphNodeKind.emotion, satellites.emotions, max: 1);

  final participationLinks = extractParticipationLinks(
    memory.content,
    localeCode: localeCode,
    knownActivities: satellites.activities.toSet(),
  );
  for (final entry in participationLinks) {
    final personId = globalEntityId('person', entry.person);
    final activityId = globalEntityId('activity', entry.activity);
    if (graphNodeIds.contains(personId) && graphNodeIds.contains(activityId)) {
      link(
        personId,
        activityId,
        Color.lerp(graphNodeKindColor(GraphNodeKind.person), graphNodeKindColor(GraphNodeKind.activity), 0.5)!,
      );
    }
  }

  for (final rel in relationsForMemory(memory)) {
    final obj = canonicalEntityLabel(rel.object);
    if (obj.isEmpty) continue;
    final kindPrefix = switch (rel.predicate) {
      '방문' => 'place',
      '감정' => 'emotion',
      '식사' => 'activity',
      _ => 'person',
    };
    final kind = switch (rel.predicate) {
      '방문' => GraphNodeKind.place,
      '감정' => GraphNodeKind.emotion,
      '식사' => GraphNodeKind.activity,
      _ => GraphNodeKind.person,
    };
    final targetId = globalEntityId(kindPrefix, obj);
    if (!graphNodeIds.contains(targetId)) continue;
    link(anchorNodeId, targetId, graphNodeKindColor(kind), label: rel.predicate, relationEdge: true);
  }
}

List<String> _peopleFromMemory(Memory memory, {String localeCode = 'ko'}) {
  return extractMemoryEntities(memory, localeCode: localeCode)
      .people
      .where((p) => !isSelfPersonLabel(p, localeCode))
      .toList();
}

bool _memoriesSharePeople(Memory a, Memory b, {String localeCode = 'ko'}) {
  final peopleA = _peopleFromMemory(a, localeCode: localeCode).toSet();
  final peopleB = _peopleFromMemory(b, localeCode: localeCode).toSet();
  if (peopleA.isEmpty || peopleB.isEmpty) return false;
  return peopleA.intersection(peopleB).isNotEmpty;
}

bool _memoriesShareStoryContext(Memory a, Memory b, {String localeCode = 'ko'}) {
  final bundleA = extractMemoryEntities(a, localeCode: localeCode);
  final bundleB = extractMemoryEntities(b, localeCode: localeCode);
  if (bundleA.places.toSet().intersection(bundleB.places.toSet()).isNotEmpty) return true;
  final titleA = bundleA.eventTitle.trim();
  final titleB = bundleB.eventTitle.trim();
  if (titleA.isNotEmpty && titleA == titleB) return true;
  final days = (a.createdAt.difference(b.createdAt)).inDays.abs();
  return days <= 14;
}

String _kindLabel(GraphNodeKind kind, String localeCode) {
  if (localeCode == 'ko') {
    return switch (kind) {
      GraphNodeKind.memory => '기억',
      GraphNodeKind.group => '하루 묶음',
      GraphNodeKind.eventHub => '이벤트',
      GraphNodeKind.person => '사람',
      GraphNodeKind.place => '장소',
      GraphNodeKind.activity => '이벤트',
      GraphNodeKind.goal => '조직',
      GraphNodeKind.emotion => '감정',
    };
  }
  return switch (kind) {
    GraphNodeKind.memory => 'Memory',
    GraphNodeKind.group => 'Day cluster',
    GraphNodeKind.eventHub => 'Event',
    GraphNodeKind.person => 'Person',
    GraphNodeKind.place => 'Place',
    GraphNodeKind.activity => 'Activity',
    GraphNodeKind.goal => 'Goal',
    GraphNodeKind.emotion => 'Emotion',
  };
}

/// 위성·엔티티 노드는 색으로 구분 — 부제는 기억·묶음 카드만.
String _nodeCardSubtitle(GraphNodeKind kind, String localeCode) {
  if (kind == GraphNodeKind.memory || kind == GraphNodeKind.group) {
    return _kindLabel(kind, localeCode);
  }
  return '';
}

/// 기억 카드가 묶음 허브로 합쳐졌을 때 graph_note 앵커 연결 대상을 찾습니다.
String? _resolveMemoryLayoutHubId(Memory related, Set<String> nodeIds) {
  final memoryId = 'memory_${related.id}';
  if (nodeIds.contains(memoryId)) return memoryId;
  final groupHubId = 'group_${clusterKeyForMemory(related).id}';
  if (nodeIds.contains(groupHubId)) return groupHubId;
  return null;
}

/// 연결선이 없는 인물·장소·활동 앵커 노드를 제거합니다.
void _pruneOrphanEntityNodes(List<GraphNodeData> nodes, List<GraphEdgeData> edges) {
  if (nodes.isEmpty) return;
  final connected = <String>{};
  for (final edge in edges) {
    connected.add(edge.fromId);
    connected.add(edge.toId);
  }
  nodes.removeWhere((node) {
    if (connected.contains(node.id)) return false;
    if (node.id.startsWith('focus_hub_')) return false;
    if (node.kind == GraphNodeKind.group || node.kind == GraphNodeKind.memory) return false;
    return node.kind == GraphNodeKind.person ||
        node.kind == GraphNodeKind.place ||
        node.kind == GraphNodeKind.activity;
  });
}

void _attachGraphNotesToAnchors({
  required List<Memory> graphNotes,
  required List<Memory> primaryMemories,
  required String localeCode,
  required String Function(String prefix, String label) globalEntityId,
  required Set<String> nodeIds,
  required void Function(GraphNodeData node) addNode,
  required void Function(String from, String to, Color color, {String? label, bool relationEdge}) link,
  required Map<String, GraphMemoryFragment> graphFragments,
}) {
  if (graphNotes.isEmpty) return;

  for (final note in graphNotes) {
    final anchor = graphNoteAnchorLabel(note);
    if (anchor == null || anchor.isEmpty) continue;

    final prefix = graphNoteAnchorEntityPrefix(note);
    final rawAnchorId = graphNoteAnchorNodeId(note) ?? globalEntityId(prefix, anchor);
    final anchorId = canonicalGraphAnchorNodeId(rawAnchorId, anchorLabel: anchor);

    Color clusterColor = Colors.blueGrey;
    var clusterId = 'graph_notes';
    var related = resolveGraphNoteRelatedMemory(note, primaryMemories);
    related ??= inferPrimaryMemoryForGraphAnchor(anchor, primaryMemories);
    if (related != null) {
      clusterColor = colorForMemory(related);
      clusterId = clusterKeyForMemory(related).id;
      if (prefix == 'place') {
        final bundle = extractMemoryEntities(related, localeCode: localeCode);
        final hubTitle = bundle.eventTitle.trim();
        if (hubTitle.isNotEmpty && hubTitle.contains(anchor.trim())) continue;
      }
    }

    final hubId = related != null ? _resolveMemoryLayoutHubId(related, nodeIds) : null;
    final anchorAlreadyOnGraph = nodeIds.contains(anchorId);
    if (!anchorAlreadyOnGraph) {
      // 미디어 전용 앵커 — 위성이 접혀 있으면 별도 썸네일 노드를 만들지 않음.
      if (isMediaOnlyGraphNote(note)) continue;
      if (hubId == null) continue;

      final kind = switch (prefix) {
        'person' => GraphNodeKind.person,
        'place' => GraphNodeKind.place,
        'activity' => GraphNodeKind.activity,
        _ => GraphNodeKind.goal,
      };
      addNode(GraphNodeData(
        id: anchorId,
        title: anchor,
        subtitle: _kindLabel(kind, localeCode),
        color: graphNodeKindColor(kind),
        kind: kind,
        size: const Size(112, 48),
        layoutClusterId: clusterId,
      ));
      nodeIds.add(anchorId);
    }

    if (hubId != null) {
      link(hubId, anchorId, clusterColor);
    }

    // 관계망 메모·미디어는 앵커 노드 썸네일/상세로만 표시 — entity_note 노드는 만들지 않음.
    continue;
  }
}

void _maybeLinkMemoryPair(
  List<GraphEdgeData> edges,
  Memory a,
  Memory b, {
  required String localeCode,
}) {
  final fromId = 'memory_${a.id}';
  final toId = 'memory_${b.id}';
  if (_hasMemoryPairEdge(edges, fromId, toId)) return;

  // 같은 날·같은 장소·같은 맥락 묶음은 허브로 이미 연결.
  if (clusterKeyForMemory(a) == clusterKeyForMemory(b)) return;

  // 기억 카드끼리 직접 연결 — 공통 인물 + (공통 장소·이벤트 또는 가까운 날짜).
  if (!_memoriesSharePeople(a, b, localeCode: localeCode)) return;
  if (!_memoriesShareStoryContext(a, b, localeCode: localeCode)) return;

  edges.add(GraphEdgeData(
    fromId: fromId,
    toId: toId,
    color: Color.lerp(colorForMemory(a), colorForMemory(b), 0.5) ?? colorForMemory(a),
    memoryToMemory: true,
  ));
}

bool _hasMemoryPairEdge(List<GraphEdgeData> edges, String fromId, String toId) {
  return edges.any(
    (e) =>
        e.memoryToMemory &&
        ((e.fromId == fromId && e.toId == toId) || (e.fromId == toId && e.toId == fromId)),
  );
}

/// 의미 유사도(보라) 선만 기억당 상한으로 줄여 복잡도 완화. 같은 날·사람 연결은 유지.
void _pruneSemanticMemoryLinks(List<GraphEdgeData> edges, {required int maxPerMemory}) {
  if (maxPerMemory <= 0) {
    edges.removeWhere((e) => e.memoryToMemory && e.semanticLink);
    return;
  }

  final semantic = <GraphEdgeData>[];
  for (final edge in edges) {
    if (edge.memoryToMemory && edge.semanticLink) semantic.add(edge);
  }
  if (semantic.isEmpty) return;

  edges.removeWhere((e) => e.memoryToMemory && e.semanticLink);

  final kept = <GraphEdgeData>[];
  final count = <String, int>{};

  bool canAdd(GraphEdgeData e) {
    final a = count[e.fromId] ?? 0;
    final b = count[e.toId] ?? 0;
    return a < maxPerMemory && b < maxPerMemory;
  }

  void register(GraphEdgeData e) {
    count[e.fromId] = (count[e.fromId] ?? 0) + 1;
    count[e.toId] = (count[e.toId] ?? 0) + 1;
    kept.add(e);
  }

  for (final edge in semantic) {
    if (canAdd(edge)) register(edge);
  }

  edges.addAll(kept);
}

String entityBridgeKey(String kindPrefix, String label) => '$kindPrefix::${label.trim()}';

Set<String> entityKeysForMemory(
  Memory memory, {
  GraphMemoryFragment? fragment,
  required String localeCode,
  String? excludeKeyword,
}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: fragment);
  final keys = entityKeysFromBundle(bundle)
      .where((k) => k != 'person::${selfPersonGraphLabel(localeCode)}')
      .toSet();
  if (excludeKeyword == null) return keys;
  final ex = excludeKeyword.trim();
  return keys.where((k) => !k.endsWith('::$ex')).toSet();
}

/// 같은 인물·장소·활동을 공유하는 서로 다른 묶음 허브를 연결.
void _addCrossClusterHubBridges({
  required List<MemoryTimelineGroup> timelineGroups,
  required Map<String, GraphMemoryFragment> graphFragments,
  required String localeCode,
  required void Function(String from, String to, Color color, {bool memoryToMemory, bool semantic, bool bridge}) link,
}) {
  final entityToClusters = <String, Set<String>>{};
  final clusterHubs = <String, String>{};

  for (final group in timelineGroups) {
    final clusterId = group.key.id;
    if (group.isGrouped) clusterHubs[clusterId] = 'group_$clusterId';
    for (final memory in group.memories) {
      final keys = entityKeysForMemory(
        memory,
        fragment: freshGraphFragmentForMemory(memory, graphFragments[memory.id]),
        localeCode: localeCode,
      );
      for (final key in keys) {
        if (!key.startsWith('person::')) continue;
        entityToClusters.putIfAbsent(key, () => {}).add(clusterId);
      }
    }
  }

  final bridgePairs = <String>{};
  const bridgeColor = Color(0xFFFFB300);

  for (final clusters in entityToClusters.values) {
    if (clusters.length < 2) continue;
    final list = clusters.toList()..sort();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final hubA = clusterHubs[list[i]];
        final hubB = clusterHubs[list[j]];
        if (hubA == null || hubB == null) continue;
        final pairKey = hubA.compareTo(hubB) < 0 ? '$hubA|$hubB' : '$hubB|$hubA';
        if (!bridgePairs.add(pairKey)) continue;
        link(hubA, hubB, bridgeColor, bridge: true);
      }
    }
  }
}

/// 포커스·교차 클러스터 — 공유 엔티티로 기억 카드끼리 브리지.
void _addSharedEntityMemoryBridges({
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> graphFragments,
  required String localeCode,
  String? excludeKeyword,
  required void Function(String from, String to, Color color, {String? label, bool relationEdge}) link,
}) {
  if (memories.length < 2) return;

  final keysByMemory = <String, Set<String>>{};
  for (final memory in memories) {
    keysByMemory[memory.id] = entityKeysForMemory(
      memory,
      fragment: freshGraphFragmentForMemory(memory, graphFragments[memory.id]),
      localeCode: localeCode,
      excludeKeyword: excludeKeyword,
    ).where((k) => k.startsWith('person::')).toSet();
  }

  const bridgeColor = Color(0xFFFFB300);
  for (var i = 0; i < memories.length; i++) {
    for (var j = i + 1; j < memories.length; j++) {
      final a = memories[i];
      final b = memories[j];
      if (clusterKeyForMemory(a) == clusterKeyForMemory(b)) continue;
      final shared = keysByMemory[a.id]!.intersection(keysByMemory[b.id]!);
      if (shared.isEmpty) continue;
      link('memory_${a.id}', 'memory_${b.id}', bridgeColor);
    }
  }
}

String? _satelliteBadgeForMemory({
  required Memory memory,
  GraphMemoryFragment? fragment,
  required String localeCode,
}) {
  return GraphEntityContext.forMemory(
    memory,
    localeCode: localeCode,
    aiFragment: fragment,
  ).badgeText;
}

/// 관계망 메모가 붙은 기억·인물이 많은 기억은 처음부터 위성을 펼칩니다.
/// [collapsedMemoryIds]에 있으면 사용자가 접은 것으로 보고 자동 펼침을 하지 않습니다.
/// 기본은 배지만 표시하고, 사용자가 레일 탭 시에만 펼칩니다.
Map<String, GraphSatelliteExpandMode> mergeDefaultSatelliteExpansions({
  required List<Memory> memories,
  required Map<String, GraphSatelliteExpandMode> userExpansions,
  required Map<String, GraphMemoryFragment> graphFragments,
  required String localeCode,
  Set<String> collapsedMemoryIds = const {},
}) {
  final merged = <String, GraphSatelliteExpandMode>{};
  for (final entry in userExpansions.entries) {
    if (!collapsedMemoryIds.contains(entry.key)) {
      merged[entry.key] = entry.value;
    }
  }

  final primary = memories.where(isLayoutPrimaryMemory).toList();
  if (primary.length <= GraphScaleConfig.autoExpandSatelliteMemoryCount) {
    for (final memory in primary) {
      if (collapsedMemoryIds.contains(memory.id)) continue;
      if (merged.containsKey(memory.id)) continue;
      final badge = _satelliteBadgeForMemory(
        memory: memory,
        fragment: graphFragments[memory.id],
        localeCode: localeCode,
      );
      if (badge != null && badge.trim().isNotEmpty) {
        merged[memory.id] = GraphSatelliteExpandMode.all;
      }
    }
  }

  return merged;
}

bool _satelliteKindAllowed(String kindPrefix, GraphSatelliteExpandMode filterMode) {
  return switch (filterMode) {
    GraphSatelliteExpandMode.person => kindPrefix == 'person',
    GraphSatelliteExpandMode.place => kindPrefix == 'place',
    GraphSatelliteExpandMode.personAndPlace =>
      kindPrefix == 'person' || kindPrefix == 'place',
    GraphSatelliteExpandMode.all => true,
  };
}

/// 드래그 시 함께 움직일 노드 (기억/허브 + 직접 연결 위성만).
Set<String> dragGroupForNode(String nodeId, List<GraphEdgeData> edges, List<GraphNodeData> nodes) {
  final nodeMap = {for (final n in nodes) n.id: n};
  final node = nodeMap[nodeId];
  if (node == null) return {nodeId};

  if (nodeId.startsWith('focus_hub_')) {
    final attached = <String>{nodeId};
    for (final edge in edges) {
      if (edge.fromId == nodeId) attached.add(edge.toId);
    }
    return attached;
  }

  if (node.kind == GraphNodeKind.group) {
    final groupId = nodeId;
    final attached = <String>{groupId};
    for (final edge in edges) {
      if (edge.memoryToMemory) continue;
      if (edge.fromId == groupId) attached.add(edge.toId);
      if (edge.toId == groupId) attached.add(edge.fromId);
    }
    for (final edge in edges) {
      if (!edge.memoryToMemory) continue;
      if (attached.contains(edge.fromId)) attached.add(edge.toId);
      if (attached.contains(edge.toId)) attached.add(edge.fromId);
    }
    return attached;
  }

  if (node.kind == GraphNodeKind.memory) {
    final attached = <String>{nodeId};
    for (final edge in edges) {
      if (edge.memoryToMemory) continue;
      if (edge.fromId == nodeId) attached.add(edge.toId);
    }
    return attached;
  }

  return {nodeId};
}

List<Set<String>> buildGraphClusters(List<GraphNodeData> nodes, List<GraphEdgeData> edges) {
  final adjacency = <String, Set<String>>{for (final node in nodes) node.id: {}};
  for (final edge in edges) {
    adjacency[edge.fromId]!.add(edge.toId);
    adjacency[edge.toId]!.add(edge.fromId);
  }

  final visited = <String>{};
  final clusters = <Set<String>>[];
  for (final node in nodes) {
    if (visited.contains(node.id)) continue;
    final cluster = <String>{};
    final queue = <String>[node.id];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!visited.add(id)) continue;
      cluster.add(id);
      queue.addAll(adjacency[id] ?? const {});
    }
    clusters.add(cluster);
  }
  return clusters;
}

Size graphCanvasSize(int layoutClusterCount) {
  if (layoutClusterCount <= 1) return const Size(1200, 900);
  final cols = math.max(1, math.sqrt(layoutClusterCount).ceil());
  final rows = (layoutClusterCount / cols).ceil();
  return Size(
    math.max(1200, cols * 400.0 + 440.0),
    math.max(900, rows * 340.0 + 440.0),
  );
}

Map<String, Offset> initialGraphPositions(
  List<GraphNodeData> nodes,
  List<GraphEdgeData> edges,
  Size canvasSize,
) {
  final positions = <String, Offset>{};
  if (nodes.isEmpty) return positions;

  final layoutClusters = <String, List<GraphNodeData>>{};
  for (final node in nodes) {
    layoutClusters.putIfAbsent(node.layoutClusterId, () => []).add(node);
  }

  final clusterKeys = layoutClusters.keys.toList();
  final cols = math.max(1, math.sqrt(clusterKeys.length).ceil());
  const spacingX = 400.0;
  const spacingY = 340.0;

  for (var i = 0; i < clusterKeys.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final center = Offset(240 + col * spacingX, 240 + row * spacingY);
    final members = layoutClusters[clusterKeys[i]]!;
    final hub = members.where((n) => n.kind == GraphNodeKind.group).toList();
    final memories = members.where((n) => n.kind == GraphNodeKind.memory).toList();
    final entityNotes = members.where((n) => n.id.startsWith('entity_note_')).toList();
    final satellites = members
        .where((n) => n.kind != GraphNodeKind.memory && n.kind != GraphNodeKind.group)
        .where((n) => !n.id.startsWith('entity_note_'))
        .toList();

    if (hub.isNotEmpty) {
      positions[hub.first.id] = center;
      for (var m = 0; m < memories.length; m++) {
        final angle = (2 * math.pi * m / math.max(memories.length, 1)) - math.pi / 2;
        positions[memories[m].id] = center + Offset(math.cos(angle) * 108, math.sin(angle) * 82);
      }
    } else if (memories.length == 1) {
      positions[memories.first.id] = center;
    } else if (memories.isNotEmpty) {
      for (var m = 0; m < memories.length; m++) {
        final angle = (2 * math.pi * m / memories.length) - math.pi / 2;
        positions[memories[m].id] = center + Offset(math.cos(angle) * 72, math.sin(angle) * 56);
      }
    }

    for (var s = 0; s < satellites.length; s++) {
      final angle = (2 * math.pi * s / math.max(satellites.length, 1)) + math.pi / 8;
      final anchor = hub.isNotEmpty
          ? center
          : (memories.isNotEmpty ? positions[memories.first.id]! : center);
      positions[satellites[s].id] = anchor + Offset(math.cos(angle) * 168, math.sin(angle) * 132);
    }

    for (final noteNode in entityNotes) {
      String? parentId;
      for (final edge in edges) {
        if (edge.toId == noteNode.id) {
          parentId = edge.fromId;
          break;
        }
      }
      if (parentId == null) continue;
      final parentPos = positions[parentId];
      if (parentPos == null) continue;
      final siblings = entityNotes.where((n) {
        for (final edge in edges) {
          if (edge.toId == n.id && edge.fromId == parentId) return true;
        }
        return false;
      }).toList();
      final index = siblings.indexWhere((n) => n.id == noteNode.id).clamp(0, siblings.length - 1);
      positions[noteNode.id] = parentPos + Offset(-4, 52 + index * 48.0);
    }
  }

  for (final node in nodes) {
    positions.putIfAbsent(node.id, () => const Offset(240, 240));
  }
  return positions;
}

class GraphEdgesPainter extends CustomPainter {
  final List<GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final Map<String, GraphNodeData> nodeMap;
  final bool isDark;

  GraphEdgesPainter({
    required this.edges,
    required this.positions,
    required this.nodeMap,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      if (!edge.bridgeLink) continue;
      _paintBridgeEdge(canvas, edge);
    }

    for (final edge in edges) {
      if (edge.bridgeLink) continue;
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;

      final control = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 36);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

      if (edge.memoryToMemory) {
        if (edge.semanticLink) {
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..color = Colors.deepPurpleAccent.withValues(alpha: isDark ? 0.85 : 0.7);
          canvas.drawPath(path, paint);
        } else {
          final dashPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = edge.color.withValues(alpha: isDark ? 0.7 : 0.5);
          _drawDashedPath(canvas, path, dashPaint, dash: 8, gap: 6);
        }
        continue;
      }

      if (edge.relationEdge) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.9 : 0.75);
        canvas.drawPath(path, paint);
        if (edge.label != null && edge.label!.isNotEmpty) {
          _paintEdgeLabel(canvas, control, edge.label!);
        }
        continue;
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = edge.color.withValues(alpha: isDark ? 0.55 : 0.45);
      canvas.drawPath(path, linePaint);
    }
  }

  void _paintEdgeLabel(Canvas canvas, Offset at, String label) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 11, fontWeight: FontWeight.w700),
    )..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 80));
    canvas.drawParagraph(
      paragraph,
      Offset(at.dx - paragraph.maxIntrinsicWidth / 2, at.dy - 18),
    );
  }

  void _paintBridgeEdge(Canvas canvas, GraphEdgeData edge) {
    final from = positions[edge.fromId];
    final to = positions[edge.toId];
    if (from == null || to == null) return;

    final control = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 48);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..color = const Color(0xFFFFB300).withValues(alpha: isDark ? 0.22 : 0.16);
    canvas.drawPath(path, glow);

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = const Color(0xFFFFB300).withValues(alpha: isDark ? 0.9 : 0.75);
    _drawDashedPath(canvas, path, dashPaint, dash: 10, gap: 5);
  }

  @override
  bool shouldRepaint(covariant GraphEdgesPainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.edges != edges || oldDelegate.isDark != isDark;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + gap;
      }
    }
  }
}
