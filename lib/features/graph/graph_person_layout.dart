import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/memory.dart';
import '../../utils/entity_canonical.dart';
import '../../utils/korean_person_names.dart';
import '../../utils/medical_entity_lexicon.dart';
import '../../utils/memory_entity_cache.dart';
import '../../utils/memory_entity_extract.dart';
import '../../utils/memory_participation_extract.dart';
import '../../utils/memory_semantic_flow.dart';
import '../../utils/organization_hierarchy.dart';
import 'graph_layout.dart';

/// 사람 중심 관계망 — 나를 중심으로 인물·관계 배치.
class PersonOverviewGraphResult {
  const PersonOverviewGraphResult({required this.layout});

  final GraphLayout layout;
}

PersonOverviewGraphResult buildPersonOverviewGraphLayout(
  List<Memory> memories, {
  String localeCode = 'ko',
}) {
  // 연인·가족·조직 계층이 있으면 의미 트리 기반으로 사람 렌즈를 구성합니다.
  for (final memory in memories) {
    if (memory.content.trim().isEmpty) continue;
    final frame = parseMemorySemanticFlow(
      '${memory.content}\n${memory.summary}',
      localeCode: localeCode,
      entityTags: memory.entities,
    );
    if (frame.organizationHierarchy.hasHierarchy) {
      return _buildFromHierarchy(
        frame.organizationHierarchy,
        localeCode: localeCode,
      );
    }
  }

  return _buildCooccurrenceFallback(memories, localeCode: localeCode);
}

PersonOverviewGraphResult _buildFromHierarchy(
  OrganizationHierarchy hierarchy, {
  required String localeCode,
}) {
  final self = selfPersonGraphLabel(localeCode);
  final nodes = <GraphNodeData>[];
  final edges = <GraphEdgeData>[];
  final ids = <String, String>{};

  String idFor(String label, {String prefix = 'person_overview'}) {
    return ids.putIfAbsent(
      label,
      () => '${prefix}_${canonicalEntityLabel(label)}',
    );
  }

  nodes.add(
    GraphNodeData(
      id: 'person_hub_self',
      title: self,
      subtitle: localeCode == 'ko' ? '나' : 'Me',
      color: graphNodeKindColor(GraphNodeKind.person),
      kind: GraphNodeKind.person,
      size: const Size(160, 76),
      layoutClusterId: 'person_overview',
      hubDepth: 0,
    ),
  );
  ids[self] = 'person_hub_self';

  // 「저는 김민수」처럼 본인 실명이 있으면 허브 옆에 표시용 연결
  String? selfRealName;
  for (final edge in hierarchy.hierarchyEdges) {
    if (edge.label == '나') {
      selfRealName = edge.to;
      break;
    }
  }

  void ensureNode(
    String label, {
    required GraphNodeKind kind,
    String? subtitle,
    int? depth,
    Size size = const Size(136, 64),
  }) {
    if (label.isEmpty || label == self) return;
    if (ids.containsKey(label)) return;
    final id = idFor(label, prefix: switch (kind) {
      GraphNodeKind.person => 'person_overview',
      GraphNodeKind.place => 'place_overview',
      GraphNodeKind.organization => 'org_overview',
      GraphNodeKind.activity => 'activity_overview',
      GraphNodeKind.event => 'event_overview',
      _ => 'entity_overview',
    });
    nodes.add(
      GraphNodeData(
        id: id,
        title: label,
        subtitle: subtitle ??
            (kind == GraphNodeKind.person
                ? (localeCode == 'ko' ? '사람' : 'Person')
                : (localeCode == 'ko' ? '관계' : 'Link')),
        color: graphNodeKindColor(kind),
        kind: kind,
        size: size,
        layoutClusterId: 'person_overview',
        hubDepth: depth,
      ),
    );
  }

  GraphNodeKind kindFor(OrganizationHierarchyNode node) {
    if (node.kind == OrganizationNodeKind.organization) {
      return _looksLikeActivity(node.label)
          ? GraphNodeKind.activity
          : GraphNodeKind.organization;
    }
    return graphKindForOrgKind(node.kind);
  }

  for (final node in hierarchy.nodes) {
    if (node.label == hierarchy.root && node.kind != OrganizationNodeKind.person) {
      // 루트 카테고리(우리 관계 등)는 허브로 쓰지 않고 건너뛰거나 약하게 표시
      if (!_isRelationNoiseLabel(node.label)) {
        ensureNode(
          node.label,
          kind: GraphNodeKind.organization,
          subtitle: localeCode == 'ko' ? '주제' : 'Topic',
          depth: 0,
        );
      }
      continue;
    }
    if (_isRelationNoiseLabel(node.label)) continue;
    ensureNode(
      node.label,
      kind: kindFor(node),
      depth: hierarchy.depthOf(node.label),
    );
  }

  if (selfRealName != null &&
      selfRealName.isNotEmpty &&
      !_isRelationNoiseLabel(selfRealName)) {
    ensureNode(
      selfRealName,
      kind: GraphNodeKind.person,
      subtitle: localeCode == 'ko' ? '나' : 'Me',
      depth: 1,
    );
    edges.add(
      GraphEdgeData(
        fromId: 'person_hub_self',
        toId: ids[selfRealName]!,
        color: AppGraphColors.person.withValues(alpha: 0.7),
        label: localeCode == 'ko' ? '본명' : 'me',
        relationEdge: true,
      ),
    );
  }

  // 계층 엣지: 부모→자식. 루트가 합성 주제면 나를 통해 연결.
  final root = hierarchy.root;
  for (final edge in hierarchy.hierarchyEdges) {
    if (_isRelationNoiseLabel(edge.to) && edge.label != '나') continue;
    final fromLabel = edge.from == root && root != null && !ids.containsKey(root)
        ? self
        : edge.from;
    final toLabel = edge.to;
    if (!ids.containsKey(toLabel)) continue;
    final fromId = ids[fromLabel] ?? 'person_hub_self';
    final toId = ids[toLabel]!;
    if (fromId == toId) continue;
    edges.add(
      GraphEdgeData(
        fromId: fromId,
        toId: toId,
        color: AppGraphColors.relationEdge.withValues(alpha: 0.8),
        label: edge.label == '나'
            ? (localeCode == 'ko' ? '나' : 'me')
            : edge.label,
        relationEdge: true,
      ),
    );
  }

  for (final rel in hierarchy.crossRelations) {
    if (!ids.containsKey(rel.subject)) {
      ensureNode(rel.subject, kind: GraphNodeKind.person, depth: 1);
    }
    if (!ids.containsKey(rel.object)) {
      ensureNode(
        rel.object,
        kind: _looksLikeActivity(rel.object)
            ? GraphNodeKind.activity
            : GraphNodeKind.person,
        depth: 1,
      );
    }
    final fromId = ids[rel.subject];
    final toId = ids[rel.object];
    if (fromId == null || toId == null || fromId == toId) continue;
    edges.add(
      GraphEdgeData(
        fromId: fromId,
        toId: toId,
        color: Colors.amber.shade700.withValues(alpha: 0.75),
        label: rel.predicate,
        relationEdge: true,
        semanticLink: true,
      ),
    );
  }

  // 허브(나)에서 직접 연결이 없는 고아 노드는 허브에 연결
  final linked = <String>{'person_hub_self'};
  for (final e in edges) {
    linked.add(e.fromId);
    linked.add(e.toId);
  }
  for (final node in nodes) {
    if (linked.contains(node.id)) continue;
    edges.add(
      GraphEdgeData(
        fromId: 'person_hub_self',
        toId: node.id,
        color: AppGraphColors.person.withValues(alpha: 0.45),
        label: localeCode == 'ko' ? '관련' : 'related',
        relationEdge: true,
      ),
    );
  }

  return PersonOverviewGraphResult(
    layout: GraphLayout(nodes: nodes, edges: edges),
  );
}

PersonOverviewGraphResult _buildCooccurrenceFallback(
  List<Memory> memories, {
  required String localeCode,
}) {
  final counts = <String, int>{};
  for (final memory in memories) {
    final bundle = MemoryEntityCache.bundle(memory, localeCode: localeCode);
    for (final person in bundle.people) {
      if (isSelfPersonLabel(person, localeCode)) continue;
      final key = stripTrailingKoreanParticles(person.trim());
      if (key.isEmpty || isBlockedPersonName(key)) continue;
      if (_isRelationNoiseLabel(key)) continue;
      if (!isFamilyRelationTerm(key) && !isLikelyKoreanPersonName(key)) continue;
      if (isMedicalGraphNoisePhrase(key) || isMedicalNonPersonToken(key)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }

  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = ranked.take(16).toList();
  final self = selfPersonGraphLabel(localeCode);

  final nodes = <GraphNodeData>[
    GraphNodeData(
      id: 'person_hub_self',
      title: self,
      subtitle: localeCode == 'ko' ? '나' : 'Me',
      color: graphNodeKindColor(GraphNodeKind.person),
      kind: GraphNodeKind.person,
      size: const Size(160, 76),
      layoutClusterId: 'person_overview',
    ),
  ];
  final edges = <GraphEdgeData>[];

  for (final entry in top) {
    final id = 'person_overview_${canonicalEntityLabel(entry.key)}';
    nodes.add(
      GraphNodeData(
        id: id,
        title: entry.key,
        subtitle: localeCode == 'ko'
            ? '추억 ${entry.value}개'
            : '${entry.value} memories',
        color: graphNodeKindColor(GraphNodeKind.person),
        kind: GraphNodeKind.person,
        size: const Size(136, 64),
        layoutClusterId: 'person_overview',
      ),
    );
    edges.add(
      GraphEdgeData(
        fromId: 'person_hub_self',
        toId: id,
        color: AppGraphColors.person.withValues(alpha: 0.55),
        label: localeCode == 'ko' ? '함께' : 'with',
        relationEdge: true,
      ),
    );
  }

  return PersonOverviewGraphResult(
    layout: GraphLayout(nodes: nodes, edges: edges),
  );
}

bool _isRelationNoiseLabel(String label) {
  const noise = {
    '연인',
    '관계',
    '우리',
    '우리 관계',
    '함께',
    '함께하는 활동',
    '활동',
    '구성',
    '분류',
    '주제',
    '친구',
    '사람',
    '나',
  };
  final t = label.trim();
  if (noise.contains(t)) return true;
  if (t.endsWith('하는 활동')) return true;
  return false;
}

bool _looksLikeActivity(String label) {
  const acts = {
    '여행',
    '운동',
    '영화',
    '영화 감상',
    '산책',
    '독서',
    '사진',
    '사진 촬영',
    '헬스',
    '러닝',
  };
  return acts.contains(label.trim()) || label.contains('감상');
}

Size personOverviewCanvasSize(int personCount) {
  final n = math.max(1, personCount);
  final diameter = 220.0 + math.sqrt(n) * 110;
  final side = math.max(1000.0, diameter * 2.2);
  return Size(side, side);
}

Map<String, Offset> initialPersonOverviewPositions(
  List<GraphNodeData> nodes,
  Size canvasSize,
) {
  final positions = <String, Offset>{};
  if (nodes.isEmpty) return positions;

  final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
  final hub = nodes.firstWhere(
    (n) => n.id == 'person_hub_self',
    orElse: () => nodes.first,
  );
  positions[hub.id] = center;

  final withDepth = nodes.where((n) => n.id != hub.id && n.hubDepth != null).toList();
  if (withDepth.isNotEmpty) {
    // depth = 행, sibling = 열 (사람 렌즈용 미니 tidy tree)
    final byDepth = <int, List<GraphNodeData>>{};
    for (final n in withDepth) {
      byDepth.putIfAbsent(n.hubDepth!, () => []).add(n);
    }
    final depths = byDepth.keys.toList()..sort();
    const rowGap = 120.0;
    const colGap = 150.0;
    for (final d in depths) {
      final row = byDepth[d]!;
      final width = (row.length - 1) * colGap;
      for (var i = 0; i < row.length; i++) {
        positions[row[i].id] = Offset(
          center.dx - width / 2 + i * colGap,
          center.dy + d * rowGap,
        );
      }
    }
    // hubDepth 없는 나머지
    final rest = nodes.where((n) => n.id != hub.id && !positions.containsKey(n.id)).toList();
    for (var i = 0; i < rest.length; i++) {
      final angle = (2 * math.pi * i / math.max(rest.length, 1)) + math.pi / 6;
      positions[rest[i].id] =
          center + Offset(math.cos(angle) * 220, math.sin(angle) * 170);
    }
    return positions;
  }

  final people = nodes.where((n) => n.id != hub.id).toList();
  final radius = math.max(200.0, 140.0 + people.length * 18.0);
  for (var i = 0; i < people.length; i++) {
    final angle =
        (2 * math.pi * i / math.max(people.length, 1)) - math.pi / 2;
    positions[people[i].id] =
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.82);
  }
  return positions;
}
