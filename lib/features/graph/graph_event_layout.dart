import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import '../../utils/entity_canonical.dart';
import '../../utils/graph_memory_card_labels.dart';
import '../../utils/graph_entity_context.dart';
import '../../utils/graph_fragment_freshness.dart';
import '../../utils/graph_meaning.dart';
import '../../utils/memory_graph_semantics.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_participation_extract.dart';
import '../../utils/memory_semantic_flow.dart';
import '../../utils/memory_theme_tags.dart';
import '../../utils/organization_hierarchy.dart';
import 'graph_chat_save.dart';
import 'graph_layout.dart';

/// 기억 본문에 기업 조직 계층(≥2 edges)이 있으면 true.
/// 기억 허브 기본 모드는 트리를 못 그리므로, 이 경우 이벤트 레이아웃을 쓰는 힌트다.
bool memoriesHaveOrganizationHierarchy(
  List<Memory> memories, {
  String localeCode = 'ko',
}) {
  for (final memory in memories) {
    if (!isLayoutPrimaryMemory(memory)) continue;
    final frame = parseMemorySemanticFlow(
      '${memory.content}\n${memory.summary}',
      localeCode: localeCode,
      entityTags: memory.entities,
    );
    if (frame.organizationHierarchy.hasHierarchy) return true;
  }
  return false;
}

/// 이벤트 허브 중심 관계망 — 이벤트 → 사람·장소·감정·기억.
GraphLayout buildEventGraphLayout(
  List<Memory> memories, {
  Map<String, String> placeCache = const {},
  Map<String, String> fullAddressCache = const {},
  Map<String, GraphMemoryFragment> graphFragments = const {},
  String localeCode = 'ko',
}) {
  final nodes = <GraphNodeData>[];
  final edges = <GraphEdgeData>[];
  final globalEntityIds = <String, String>{};
  final graphNodeIds = <String>{};

  GraphMemoryFragment? fragmentFor(Memory memory) =>
      freshGraphFragmentForMemory(memory, graphFragments[memory.id]);

  String globalEntityId(String prefix, String label) {
    return globalEntityIds.putIfAbsent(
      '$prefix::$label',
      () => '${prefix}_$label',
    );
  }

  void addNode(GraphNodeData node) {
    nodes.add(node);
    graphNodeIds.add(node.id);
  }

  void linkLabeled(String from, String to, Color color, String label) {
    edges.add(
      GraphEdgeData(
        fromId: from,
        toId: to,
        color: color,
        label: label,
        relationEdge: true,
      ),
    );
  }

  final eventGroups = <String, List<Memory>>{};
  for (final memory in memories) {
    if (!isLayoutPrimaryMemory(memory)) continue;
    final hub = eventHubForMemory(memory);
    final bundle = extractMemoryEntities(
      memory,
      localeCode: localeCode,
      aiFragment: fragmentFor(memory),
    );
    final groupKey = eventGroupKeyForMemory(
      memory: memory,
      bundle: bundle,
      storedHub: hub,
      localeCode: localeCode,
    );
    eventGroups.putIfAbsent(groupKey, () => []).add(memory);
  }

  for (final entry in eventGroups.entries) {
    final groupMemories = entry.value
      ..sort(
        (a, b) => importanceForMemory(b).compareTo(importanceForMemory(a)),
      );
    final anchor = groupMemories.first;
    final anchorFragment = fragmentFor(anchor);
    final anchorCtx = GraphEntityContext.forMemory(
      anchor,
      localeCode: localeCode,
      aiFragment: anchorFragment,
    );
    final eventTitle = normalizeEventTitle(
      anchorCtx.hubTitle.isNotEmpty
          ? anchorCtx.hubTitle
          : _dayLabel(anchor.createdAt, localeCode),
    );
    final eventId = entry.key.startsWith('title::')
        ? entry.key.substring('title::'.length)
        : entry.key.substring('day::'.length);
    final clusterId = 'event_$eventId';
    final stars = importanceStars(
      groupMemories.map(importanceForMemory).fold(1, (a, b) => a > b ? a : b),
    );
    final eventNodeId = 'event_hub_$eventId';

    addNode(
      GraphNodeData(
        id: eventNodeId,
        title: eventTitle,
        subtitle: localeCode == 'ko' ? '이벤트 $stars' : 'Event $stars',
        dateLabel: _dayLabel(groupMemories.first.createdAt, localeCode),
        color: const Color(0xFF5C6BC0),
        kind: GraphNodeKind.eventHub,
        size: const Size(188, 96),
        layoutClusterId: clusterId,
      ),
    );

    final people = <String>{};
    final places = <String>{};
    final emotions = <String>{};
    final foods = <String>{};
    final combinedText = groupMemories
        .map((m) => '${m.content}\n${m.summary}')
        .join('\n');
    final combinedEntities = [
      for (final m in groupMemories) ...m.entities,
    ];
    final careFrame = parseMemorySemanticFlow(
      combinedText,
      localeCode: localeCode,
      entityTags: combinedEntities,
    );
    final depthTree = careFrame.depthTree;
    final organizationHierarchy = careFrame.organizationHierarchy;
    final hasCareHierarchy = depthTree.hasDepth;
    final hasOrganizationHierarchy = organizationHierarchy.hasHierarchy;

    final rootHubSubtitle = depthTree.primaryEvent?.isNotEmpty == true
        ? (localeCode == 'ko'
              ? '${depthTree.primaryEvent} · $stars'
              : '${depthTree.primaryEvent} · Event $stars')
        : (localeCode == 'ko' ? '이벤트 $stars' : 'Event $stars');

    if (hasCareHierarchy || hasOrganizationHierarchy) {
      final rootIdx = nodes.indexWhere((n) => n.id == eventNodeId);
      if (rootIdx >= 0) {
        final prev = nodes[rootIdx];
        final careRootTitle = hasOrganizationHierarchy
            ? organizationHierarchy.root!
            : _careEventRootTitle(
                careFrame: careFrame,
                fallback: eventTitle,
                localeCode: localeCode,
              );
        nodes[rootIdx] = GraphNodeData(
          id: prev.id,
          title: careRootTitle,
          subtitle: rootHubSubtitle,
          dateLabel: prev.dateLabel,
          placeLabel: prev.placeLabel,
          color: prev.color,
          kind: prev.kind,
          size: prev.size,
          layoutClusterId: prev.layoutClusterId,
          hubDepth: 0,
          satelliteBadge: prev.satelliteBadge,
        );
      }
    }

    for (final memory in groupMemories) {
      final ctx = GraphEntityContext.forMemory(
        memory,
        localeCode: localeCode,
        aiFragment: fragmentFor(memory),
      );
      for (final rel in relationsForMemory(memory)) {
        final obj = canonicalEntityLabel(rel.object);
        if (!entityLabelReferencedInMemory(obj, memory)) continue;
        if (!shouldShowGraphSatelliteLabel(obj, hubTitle: eventTitle)) continue;
        switch (rel.predicate) {
          case '동행':
            people.add(obj);
          case '방문':
            places.add(obj);
          case '감정':
            emotions.add(obj);
          case '식사':
            foods.add(obj);
          default:
            break;
        }
      }
      for (final p in ctx.visibleSatellites.people) {
        people.add(canonicalEntityLabel(p));
      }
      for (final p in ctx.visibleSatellites.places) {
        places.add(canonicalEntityLabel(p));
      }
      emotions.addAll(
        emotionTagsForMemory(
          memory,
          localeCode: localeCode,
        ).where((e) => entityLabelReferencedInMemory(e, memory)),
      );
      foods.addAll(
        foodTagsForMemory(
          memory,
        ).where((e) => entityLabelReferencedInMemory(e, memory)),
      );
    }

    void attachSatellite(
      String prefix,
      GraphNodeKind kind,
      String label,
      String relLabel,
      Color color,
    ) {
      if (label.isEmpty || isSelfPersonLabel(label, localeCode)) return;
      if (!shouldShowGraphSatelliteLabel(label, hubTitle: eventTitle)) return;
      final id = globalEntityId(prefix, label);
      if (!graphNodeIds.contains(id)) {
        addNode(
          GraphNodeData(
            id: id,
            title: label,
            subtitle: '',
            color: color,
            kind: kind,
            size: const Size(112, 48),
            layoutClusterId: clusterId,
          ),
        );
      }
      linkLabeled(eventNodeId, id, color, relLabel);
    }

    if (hasOrganizationHierarchy) {
      _attachOrganizationHierarchy(
        hierarchy: organizationHierarchy,
        rootNodeId: eventNodeId,
        clusterId: clusterId,
        globalEntityId: globalEntityId,
        graphNodeIds: graphNodeIds,
        addNode: addNode,
        edges: edges,
      );
    } else if (hasCareHierarchy) {
      _attachDepthCareTree(
        tree: depthTree,
        rootNodeId: eventNodeId,
        clusterId: clusterId,
        localeCode: localeCode,
        globalEntityId: globalEntityId,
        graphNodeIds: graphNodeIds,
        addNode: addNode,
        linkLabeled: linkLabeled,
      );
    } else {
      for (final p in people.take(8)) {
        attachSatellite(
          'person',
          GraphNodeKind.person,
          p,
          localeCode == 'ko' ? '동행' : 'with',
          Colors.pink.shade400,
        );
      }
      for (final p in places.take(4)) {
        attachSatellite(
          'place',
          GraphNodeKind.place,
          p,
          localeCode == 'ko' ? '방문' : 'visit',
          Colors.teal.shade500,
        );
      }
    }

    // 계층(조직·가족) 모드에서는 감정/식사 위성을 붙이지 않아 트리를 단순하게 유지합니다.
    if (!hasOrganizationHierarchy) {
      for (final e in emotions.take(3)) {
        attachSatellite(
          'emotion',
          GraphNodeKind.emotion,
          e,
          localeCode == 'ko' ? '감정' : 'felt',
          Colors.deepOrange.shade400,
        );
      }
      for (final f in foods.take(2)) {
        attachSatellite(
          'food',
          GraphNodeKind.activity,
          f,
          localeCode == 'ko' ? '식사' : 'ate',
          Colors.orange.shade600,
        );
      }
    }

    final memoryLimit = hasOrganizationHierarchy ? 0 : 6;
    for (final memory in groupMemories.take(memoryLimit)) {
      final memoryId = 'memory_${memory.id}';
      final cardLabels = buildGraphMemoryCardLabels(
        memory,
        placeCache,
        fullAddressCache,
        localeCode: localeCode,
      );
      final title = graphMeaningSentence(memory, localeCode: localeCode);
      if (groupMemories.length == 1 &&
          normalizeEventTitle(title) == eventTitle) {
        continue;
      }
      addNode(
        GraphNodeData(
          id: memoryId,
          title: title,
          subtitle: localeCode == 'ko'
              ? '기억 ${importanceStars(importanceForMemory(memory))}'
              : 'Memory',
          dateLabel: cardLabels.metaLine,
          placeLabel: cardLabels.addressLine,
          color: const Color(0xFF5C6BC0).withValues(alpha: 0.85),
          kind: GraphNodeKind.memory,
          size: const Size(180, 108),
          layoutClusterId: clusterId,
        ),
      );
      linkLabeled(
        eventNodeId,
        memoryId,
        const Color(0xFF5C6BC0),
        localeCode == 'ko' ? '기록' : 'logged',
      );
    }
  }

  return GraphLayout(nodes: nodes, edges: edges);
}

void _attachOrganizationHierarchy({
  required OrganizationHierarchy hierarchy,
  required String rootNodeId,
  required String clusterId,
  required String Function(String prefix, String label) globalEntityId,
  required Set<String> graphNodeIds,
  required void Function(GraphNodeData node) addNode,
  required List<GraphEdgeData> edges,
}) {
  final root = hierarchy.root;
  if (root == null || root.isEmpty) return;
  final nodeIds = <String, String>{root: rootNodeId};

  String nodeIdFor(String label) {
    return nodeIds.putIfAbsent(label, () {
      final node = hierarchy.nodes.firstWhere(
        (n) => n.label == label,
        orElse: () => OrganizationHierarchyNode(
          label: label,
          kind: OrganizationNodeKind.organization,
        ),
      );
      final prefix = switch (node.kind) {
        OrganizationNodeKind.organization => 'org',
        OrganizationNodeKind.person => 'person',
        OrganizationNodeKind.project => 'project',
        OrganizationNodeKind.place => 'place',
        OrganizationNodeKind.event => 'event',
        OrganizationNodeKind.activity => 'activity',
        OrganizationNodeKind.food => 'food',
        OrganizationNodeKind.pet => 'pet',
        OrganizationNodeKind.item => 'item',
      };
      return globalEntityId(prefix, label);
    });
  }

  for (final node in hierarchy.nodes) {
    if (node.label == root) continue;
    final id = nodeIdFor(node.label);
    if (graphNodeIds.contains(id)) continue;
    final kind = graphKindForOrgKind(node.kind);
    final color = graphNodeKindColor(kind);
    final subtitle = switch (node.kind) {
      OrganizationNodeKind.organization => '조직',
      OrganizationNodeKind.person => '구성원',
      OrganizationNodeKind.project => '프로젝트',
      OrganizationNodeKind.place => '장소',
      OrganizationNodeKind.event => '이벤트',
      OrganizationNodeKind.activity => '활동',
      OrganizationNodeKind.food => '음식',
      OrganizationNodeKind.pet => '반려',
      OrganizationNodeKind.item => '항목',
    };
    final inTree = node.label == root ||
        hierarchy.hierarchyEdges.any(
          (e) => e.from == node.label || e.to == node.label,
        );
    addNode(
      GraphNodeData(
        id: id,
        title: node.label,
        subtitle: subtitle,
        color: color,
        kind: kind,
        size: Size(
          node.kind == OrganizationNodeKind.organization ? 140 : 128,
          node.kind == OrganizationNodeKind.person ? 72 : 58,
        ),
        layoutClusterId: clusterId,
        hubDepth: node.kind == OrganizationNodeKind.project || !inTree
            ? null
            : hierarchy.depthOf(node.label),
      ),
    );
  }

  for (final edge in hierarchy.hierarchyEdges) {
    edges.add(
      GraphEdgeData(
        fromId: nodeIdFor(edge.from),
        toId: nodeIdFor(edge.to),
        color: const Color(0xFF7E57C2),
        label: edge.label,
        relationEdge: true,
      ),
    );
  }

  for (final relation in hierarchy.crossRelations) {
    edges.add(
      GraphEdgeData(
        fromId: nodeIdFor(relation.subject),
        toId: nodeIdFor(relation.object),
        color: Colors.amber.shade700,
        label: relation.predicate,
        relationEdge: true,
        semanticLink: true,
      ),
    );
  }
}

void _attachDepthCareTree({
  required CareDepthTree tree,
  required String rootNodeId,
  required String clusterId,
  required String localeCode,
  required String Function(String prefix, String label) globalEntityId,
  required Set<String> graphNodeIds,
  required void Function(GraphNodeData node) addNode,
  required void Function(String from, String to, Color color, String label)
  linkLabeled,
}) {
  final branchColor = Colors.teal.shade600;
  final deptHubColor = const Color(0xFF7E57C2);
  final personColor = Colors.pink.shade400;

  for (final branch in tree.branches) {
    final branchKey = branch.isEscort
        ? 'escort::${branch.escortName}::${branch.escortRole}'
        : 'org::${branch.organization}';
    final branchId = globalEntityId('branch', branchKey);
    if (!graphNodeIds.contains(branchId)) {
      addNode(
        GraphNodeData(
          id: branchId,
          title: branch.branchTitle,
          subtitle: branch.isEscort
              ? (localeCode == 'ko'
                    ? '인솔 · ${branch.organizationContext ?? ''}'
                    : 'escort')
              : (localeCode == 'ko' ? '방문 기관' : 'site'),
          color: branch.isEscort ? Colors.indigo.shade400 : branchColor,
          kind: branch.isEscort
              ? GraphNodeKind.person
              : GraphNodeKind.organization,
          size: Size(branch.isEscort ? 124 : 132, branch.isEscort ? 52 : 52),
          layoutClusterId: clusterId,
          hubDepth: 1,
        ),
      );
    }
    linkLabeled(
      rootNodeId,
      branchId,
      branch.isEscort ? Colors.indigo.shade400 : branchColor,
      branch.isEscort
          ? (localeCode == 'ko' ? '인솔' : 'escort')
          : (tree.primaryEvent ?? (localeCode == 'ko' ? '방문' : 'visit')),
    );

    for (final dept in branch.departments) {
      final deptId = globalEntityId(
        'depth_dept',
        '$branchKey::${dept.department}',
      );
      if (!graphNodeIds.contains(deptId)) {
        addNode(
          GraphNodeData(
            id: deptId,
            title: dept.department,
            subtitle:
                dept.organizationContext ??
                (localeCode == 'ko' ? '진료과' : 'dept'),
            color: deptHubColor,
            kind: GraphNodeKind.eventHub,
            size: const Size(116, 48),
            layoutClusterId: clusterId,
            hubDepth: 2,
          ),
        );
      }
      linkLabeled(
        branchId,
        deptId,
        deptHubColor,
        localeCode == 'ko' ? '진료과' : 'dept',
      );

      for (final patient in dept.patients) {
        final personId = globalEntityId('person', patient.name);
        if (!graphNodeIds.contains(personId)) {
          addNode(
            GraphNodeData(
              id: personId,
              title: patient.name,
              subtitle: patient.role,
              color: personColor,
              kind: GraphNodeKind.person,
              size: const Size(104, 44),
              layoutClusterId: clusterId,
              hubDepth: 3,
            ),
          );
        }
        linkLabeled(
          deptId,
          personId,
          personColor,
          localeCode == 'ko' ? '진료' : 'care',
        );

        final companionName = patient.companionName?.trim();
        final companionRole = patient.companionRole?.trim();
        if (companionName != null && companionName.isNotEmpty) {
          final companionId = globalEntityId(
            'companion',
            '$companionName::$companionRole',
          );
          if (!graphNodeIds.contains(companionId)) {
            addNode(
              GraphNodeData(
                id: companionId,
                title: companionName,
                subtitle: companionRole ?? (localeCode == 'ko' ? '동행' : 'with'),
                color: Colors.deepOrange.shade300,
                kind: GraphNodeKind.person,
                size: const Size(96, 40),
                layoutClusterId: clusterId,
                hubDepth: 4,
              ),
            );
          }
          linkLabeled(
            personId,
            companionId,
            Colors.deepOrange.shade300,
            companionRole ?? (localeCode == 'ko' ? '동행' : 'with'),
          );
        }
      }
    }
  }
}

String _careEventRootTitle({
  required MemorySemanticFrame careFrame,
  required String fallback,
  required String localeCode,
}) {
  final event = careFrame.primaryEvent?.trim();
  if (event != null && event.contains('현황')) return event;
  if (event != null && event.contains('외진')) {
    return localeCode == 'ko' ? '오늘 외진현황' : 'Today outreach';
  }
  final origin = careFrame.reportingOrganization?.trim();
  if (origin != null && origin.isNotEmpty) return origin;
  return fallback;
}

String _dayLabel(DateTime at, String localeCode) {
  if (localeCode == 'ko') return '${at.year}.${at.month}.${at.day}';
  return '${at.year}-${at.month}-${at.day}';
}

Size eventGraphCanvasSize(int eventCount, {int hierarchyNodeCount = 0}) {
  if (hierarchyNodeCount >= 12) {
    final width = math.max(1600.0, 220.0 + hierarchyNodeCount * 56.0);
    final height = math.max(1100.0, 280.0 + hierarchyNodeCount * 28.0);
    return Size(width, height);
  }
  if (eventCount <= 2) return const Size(1200, 900);
  if (eventCount <= 5) return const Size(1500, 1100);
  return const Size(1800, 1300);
}

Map<String, Offset> initialEventGraphPositions(
  List<GraphNodeData> nodes,
  List<GraphEdgeData> edges,
  Size canvasSize,
) {
  final positions = <String, Offset>{};
  final hubs = nodes.where((n) => n.kind == GraphNodeKind.eventHub).toList();
  if (hubs.isEmpty) return initialGraphPositions(nodes, edges, canvasSize);

  final cols = math.max(1, math.sqrt(hubs.length).ceil());
  const spacingX = 520.0;
  const spacingY = 480.0;

  for (var i = 0; i < hubs.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final center = Offset(320 + col * spacingX, 160 + row * spacingY);
    positions[hubs[i].id] = center;

    final clusterId = hubs[i].layoutClusterId;
    final clusterNodes = nodes
        .where((n) => n.layoutClusterId == clusterId)
        .toList();
    final hasDepthTree = clusterNodes.any((n) => n.hubDepth != null);

    if (hasDepthTree) {
      _applyDepthTreePositions(
        positions: positions,
        origin: center,
        nodes: nodes,
        edges: edges,
        clusterId: clusterId,
        rootHubId: hubs[i].id,
      );
      _placeNonHierarchySatellites(
        positions: positions,
        nodes: clusterNodes,
        rootHubId: hubs[i].id,
        treeOrigin: positions[hubs[i].id] ?? center,
      );
    } else {
      // 원형 궤도 대신 허브 아래 트리 행으로 배치해 교차·엉킴을 줄입니다.
      final satellites = clusterNodes
          .where(
            (n) =>
                n.kind != GraphNodeKind.eventHub &&
                n.kind != GraphNodeKind.memory,
          )
          .toList()
        ..sort((a, b) {
          final k = a.kind.index.compareTo(b.kind.index);
          return k != 0 ? k : a.title.compareTo(b.title);
        });
      final memories = clusterNodes
          .where((n) => n.kind == GraphNodeKind.memory)
          .toList();
      const colGap = 148.0;
      const rowGap = 112.0;
      if (memories.isNotEmpty) {
        final width = (memories.length - 1) * colGap;
        for (var m = 0; m < memories.length; m++) {
          positions[memories[m].id] = Offset(
            center.dx - width / 2 + m * colGap,
            center.dy + rowGap,
          );
        }
      }
      if (satellites.isNotEmpty) {
        final width = (satellites.length - 1) * colGap;
        final y = center.dy + rowGap * (memories.isEmpty ? 1 : 2);
        for (var s = 0; s < satellites.length; s++) {
          positions[satellites[s].id] = Offset(
            center.dx - width / 2 + s * colGap,
            y,
          );
        }
      }
    }
  }

  for (final node in nodes) {
    positions.putIfAbsent(node.id, () => const Offset(240, 240));
  }
  return positions;
}

/// 계층 트리 밖 노드(프로젝트·미배치 위성)를 트리 오른쪽에 정렬합니다.
void _placeNonHierarchySatellites({
  required Map<String, Offset> positions,
  required List<GraphNodeData> nodes,
  required String rootHubId,
  required Offset treeOrigin,
}) {
  final placed = nodes
      .where((n) => positions.containsKey(n.id) && n.id != rootHubId)
      .map((n) => positions[n.id]!)
      .toList();
  var maxX = treeOrigin.dx;
  var minY = treeOrigin.dy;
  var maxY = treeOrigin.dy;
  for (final p in placed) {
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }

  final extras = nodes
      .where(
        (n) =>
            n.id != rootHubId &&
            n.hubDepth == null &&
            n.kind != GraphNodeKind.eventHub,
      )
      .toList();
  for (var i = 0; i < extras.length; i++) {
    if (positions.containsKey(extras[i].id) &&
        (positions[extras[i].id]! - treeOrigin).distance > 8) {
      // 이미 트리 배치됨
      continue;
    }
    positions[extras[i].id] = Offset(
      maxX + 180,
      minY + i * 72.0,
    );
  }

  // 부부·배우자처럼 같은 깊이 교차 관계는 레이아웃 후 옆자리로 보정하지 않음
  // (semantic 곡선만 표시).
}

/// Top-down tidy tree: depth = 행(Y), sibling = 열(X).
void _applyDepthTreePositions({
  required Map<String, Offset> positions,
  required Offset origin,
  required List<GraphNodeData> nodes,
  required List<GraphEdgeData> edges,
  required String clusterId,
  required String rootHubId,
}) {
  final clusterNodes = nodes
      .where((n) => n.layoutClusterId == clusterId)
      .toList();
  if (!clusterNodes.any((n) => n.hubDepth != null)) return;

  final nodeById = {for (final n in clusterNodes) n.id: n};
  final children = <String, List<String>>{};
  for (final edge in edges) {
    if (!edge.relationEdge || edge.semanticLink) continue;
    final from = nodeById[edge.fromId];
    final to = nodeById[edge.toId];
    if (from == null || to == null) continue;
    // 기억 카드·감정 등은 계층 슬롯을 먹지 않게 제외
    if (to.kind == GraphNodeKind.memory ||
        to.kind == GraphNodeKind.emotion ||
        to.kind == GraphNodeKind.activity) {
      continue;
    }
    // 계층 노드는 hubDepth가 있거나 루트에서 나가는 소속/자녀 엣지
    final isHierarchyLabel =
        edge.label == '소속' ||
        edge.label == '자녀' ||
        edge.label == '구성' ||
        (from.hubDepth != null && to.hubDepth != null);
    if (!isHierarchyLabel && to.hubDepth == null) continue;
    children.putIfAbsent(edge.fromId, () => []);
    if (!children[edge.fromId]!.contains(edge.toId)) {
      children[edge.fromId]!.add(edge.toId);
    }
  }

  // 형제 순서를 안정적으로: 제목 가나다
  for (final entry in children.entries) {
    entry.value.sort((a, b) {
      final ta = nodeById[a]?.title ?? a;
      final tb = nodeById[b]?.title ?? b;
      return ta.compareTo(tb);
    });
  }

  const rowGap = 118.0;
  const colGap = 156.0;

  double layoutNode(String nodeId, double xCursor, int depth) {
    final kids = (children[nodeId] ?? const [])
        .where(nodeById.containsKey)
        .toList();
    final y = origin.dy + depth * rowGap;
    if (kids.isEmpty) {
      positions[nodeId] = Offset(xCursor, y);
      return xCursor + colGap;
    }
    final start = xCursor;
    for (final kid in kids) {
      xCursor = layoutNode(kid, xCursor, depth + 1);
    }
    final mid = (start + xCursor - colGap) / 2;
    positions[nodeId] = Offset(mid, y);
    return xCursor;
  }

  final branches = (children[rootHubId] ?? const [])
      .where(nodeById.containsKey)
      .toList();
  if (branches.isEmpty) return;

  positions[rootHubId] = origin;
  // 자식 서브트리 폭을 측정한 뒤 루트 기준으로 가운데 정렬
  double measureWidth(String nodeId) {
    final kids = (children[nodeId] ?? const [])
        .where(nodeById.containsKey)
        .toList();
    if (kids.isEmpty) return colGap;
    return kids.map(measureWidth).fold<double>(0, (a, b) => a + b);
  }

  final totalWidth = branches.map(measureWidth).fold<double>(0, (a, b) => a + b);
  var cursor = origin.dx - totalWidth / 2;
  for (final branch in branches) {
    cursor = layoutNode(branch, cursor, 1);
  }
  positions[rootHubId] = Offset(origin.dx, origin.dy);

  // 배우자(부부) 교차: 같은 Y에 옆에 붙이기
  for (final edge in edges) {
    if (!edge.semanticLink) continue;
    if (edge.label != '부부') continue;
    final a = positions[edge.fromId];
    final b = positions[edge.toId];
    if (a == null && b == null) continue;
    if (a != null && b == null) {
      positions[edge.toId] = Offset(a.dx + colGap * 0.85, a.dy);
    } else if (b != null && a == null) {
      positions[edge.fromId] = Offset(b.dx - colGap * 0.85, b.dy);
    } else if (a != null && b != null) {
      final midY = (a.dy + b.dy) / 2;
      if ((a.dx - b.dx).abs() < colGap * 0.5) {
        positions[edge.toId] = Offset(a.dx + colGap * 0.85, midY);
        positions[edge.fromId] = Offset(a.dx, midY);
      } else {
        positions[edge.fromId] = Offset(a.dx, midY);
        positions[edge.toId] = Offset(b.dx, midY);
      }
    }
  }
}

