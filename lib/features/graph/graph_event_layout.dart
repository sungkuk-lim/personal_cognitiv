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
import '../../utils/memory_theme_tags.dart';
import 'graph_chat_save.dart';
import 'graph_layout.dart';

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
    return globalEntityIds.putIfAbsent('$prefix::$label', () => '${prefix}_$label');
  }

  void addNode(GraphNodeData node) {
    nodes.add(node);
    graphNodeIds.add(node.id);
  }

  void linkLabeled(String from, String to, Color color, String label) {
    edges.add(GraphEdgeData(
      fromId: from,
      toId: to,
      color: color,
      label: label,
      relationEdge: true,
    ));
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
      ..sort((a, b) => importanceForMemory(b).compareTo(importanceForMemory(a)));
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

    addNode(GraphNodeData(
      id: eventNodeId,
      title: eventTitle,
      subtitle: localeCode == 'ko' ? '이벤트 $stars' : 'Event $stars',
      dateLabel: _dayLabel(groupMemories.first.createdAt, localeCode),
      color: const Color(0xFF5C6BC0),
      kind: GraphNodeKind.eventHub,
      size: const Size(188, 96),
      layoutClusterId: clusterId,
    ));

    final people = <String>{};
    final places = <String>{};
    final emotions = <String>{};
    final foods = <String>{};

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
        emotionTagsForMemory(memory, localeCode: localeCode)
            .where((e) => entityLabelReferencedInMemory(e, memory)),
      );
      foods.addAll(
        foodTagsForMemory(memory).where((e) => entityLabelReferencedInMemory(e, memory)),
      );
    }

    void attachSatellite(String prefix, GraphNodeKind kind, String label, String relLabel, Color color) {
      if (label.isEmpty || isSelfPersonLabel(label, localeCode)) return;
      if (!shouldShowGraphSatelliteLabel(label, hubTitle: eventTitle)) return;
      final id = globalEntityId(prefix, label);
      if (!graphNodeIds.contains(id)) {
        addNode(GraphNodeData(
          id: id,
          title: label,
          subtitle: '',
          color: color,
          kind: kind,
          size: const Size(112, 48),
          layoutClusterId: clusterId,
        ));
      }
      linkLabeled(eventNodeId, id, color, relLabel);
    }

    for (final p in people.take(8)) {
      attachSatellite('person', GraphNodeKind.person, p, localeCode == 'ko' ? '동행' : 'with', Colors.pink.shade400);
    }
    for (final p in places.take(4)) {
      attachSatellite('place', GraphNodeKind.place, p, localeCode == 'ko' ? '방문' : 'visit', Colors.teal.shade500);
    }
    for (final e in emotions.take(3)) {
      attachSatellite('emotion', GraphNodeKind.emotion, e, localeCode == 'ko' ? '감정' : 'felt', Colors.deepOrange.shade400);
    }
    for (final f in foods.take(2)) {
      attachSatellite('food', GraphNodeKind.activity, f, localeCode == 'ko' ? '식사' : 'ate', Colors.orange.shade600);
    }

    for (final memory in groupMemories.take(6)) {
      final memoryId = 'memory_${memory.id}';
      final cardLabels = buildGraphMemoryCardLabels(
        memory,
        placeCache,
        fullAddressCache,
        localeCode: localeCode,
      );
      final title = graphMeaningSentence(memory, localeCode: localeCode);
      if (groupMemories.length == 1 && normalizeEventTitle(title) == eventTitle) {
        continue;
      }
      addNode(GraphNodeData(
        id: memoryId,
        title: title,
        subtitle: localeCode == 'ko' ? '기억 ${importanceStars(importanceForMemory(memory))}' : 'Memory',
        dateLabel: cardLabels.metaLine,
        placeLabel: cardLabels.addressLine,
        color: const Color(0xFF5C6BC0).withValues(alpha: 0.85),
        kind: GraphNodeKind.memory,
        size: const Size(180, 108),
        layoutClusterId: clusterId,
      ));
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

String _dayLabel(DateTime at, String localeCode) {
  if (localeCode == 'ko') return '${at.year}.${at.month}.${at.day}';
  return '${at.year}-${at.month}-${at.day}';
}

Size eventGraphCanvasSize(int eventCount) {
  if (eventCount <= 2) return const Size(1200, 900);
  if (eventCount <= 5) return const Size(1500, 1100);
  return const Size(1800, 1300);
}

Map<String, Offset> initialEventGraphPositions(List<GraphNodeData> nodes, List<GraphEdgeData> edges, Size canvasSize) {
  final positions = <String, Offset>{};
  final hubs = nodes.where((n) => n.kind == GraphNodeKind.eventHub).toList();
  if (hubs.isEmpty) return initialGraphPositions(nodes, edges, canvasSize);

  final cols = math.max(1, math.sqrt(hubs.length).ceil());
  const spacingX = 420.0;
  const spacingY = 360.0;

  for (var i = 0; i < hubs.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final center = Offset(260 + col * spacingX, 260 + row * spacingY);
    positions[hubs[i].id] = center;

    final clusterId = hubs[i].layoutClusterId;
    final satellites = nodes
        .where((n) => n.layoutClusterId == clusterId && n.kind != GraphNodeKind.eventHub && n.kind != GraphNodeKind.memory)
        .toList();
    final memories = nodes
        .where((n) => n.layoutClusterId == clusterId && n.kind == GraphNodeKind.memory)
        .toList();

    for (var s = 0; s < satellites.length; s++) {
      final angle = (2 * math.pi * s / math.max(satellites.length, 1)) - math.pi / 2;
      positions[satellites[s].id] = center + Offset(math.cos(angle) * 140, math.sin(angle) * 110);
    }
    for (var m = 0; m < memories.length; m++) {
      final angle = (2 * math.pi * m / math.max(memories.length, 1)) + math.pi / 6;
      positions[memories[m].id] = center + Offset(math.cos(angle) * 220, math.sin(angle) * 170);
    }
  }

  for (final node in nodes) {
    positions.putIfAbsent(node.id, () => const Offset(240, 240));
  }
  return positions;
}
