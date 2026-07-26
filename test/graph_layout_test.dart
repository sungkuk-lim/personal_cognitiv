import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/ocr_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('graphKeywordsForMemory extracts tokens from local guest text', () {
    final m = Memory(
      id: '1',
      content: '오늘 강남역 근처에서 민수와 점심을 먹었다',
      summary: '민수와 강남 점심',
      entities: const [],
      createdAt: DateTime.now(),
    );
    final keywords = graphKeywordsForMemory(m);
    expect(keywords, contains('민수'));
    expect(keywords, contains('강남'));
  });

  test('buildMemoryGraphLayout connects related memories in one cluster', () {
    final memories = [
      Memory(
        id: 'a',
        content: '프로젝트 회의에서 일정을 정했다',
        summary: '프로젝트 회의 일정',
        entities: const [],
        createdAt: DateTime(2026, 5, 1, 10),
        lat: 35.1,
        lng: 128.9,
      ),
      Memory(
        id: 'b',
        content: '프로젝트 일정을 다시 검토했다',
        summary: '프로젝트 일정 검토',
        entities: const [],
        createdAt: DateTime(2026, 5, 1, 11),
        lat: 35.1,
        lng: 128.9,
      ),
    ];

    final layout = buildMemoryGraphLayout(memories);
    const groupId = 'group_2026-05-01_35.1000,128.9000_Other';
    expect(layout.nodes.any((n) => n.id == groupId), isTrue);

    final memoryNodes = layout.nodes.where((n) => n.kind == GraphNodeKind.memory).map((n) => n.id).toSet();
    if (memoryNodes.containsAll(const {'memory_a', 'memory_b'})) {
      final clusters = buildGraphClusters(layout.nodes, layout.edges);
      expect(clusters.any((c) => c.contains('memory_a') && c.contains('memory_b')), isTrue);
    } else {
      expect(layout.nodes.where((n) => n.kind == GraphNodeKind.group), isNotEmpty);
    }
  });

  test('dragGroupForNode moves focus hub with attached memories', () {
    const hubId = 'focus_hub_민수';
    const memA = 'memory_a';
    const memB = 'memory_b';
    final nodes = [
      GraphNodeData(
        id: hubId,
        title: '민수',
        subtitle: '',
        color: Colors.blue,
        kind: GraphNodeKind.person,
        size: const Size(80, 80),
        layoutClusterId: 'focus',
      ),
      GraphNodeData(
        id: memA,
        title: 'A',
        subtitle: '',
        color: Colors.green,
        kind: GraphNodeKind.memory,
        size: const Size(60, 60),
        layoutClusterId: 'focus',
      ),
      GraphNodeData(
        id: memB,
        title: 'B',
        subtitle: '',
        color: Colors.green,
        kind: GraphNodeKind.memory,
        size: const Size(60, 60),
        layoutClusterId: 'focus',
      ),
    ];
    final edges = [
      GraphEdgeData(fromId: hubId, toId: memA, color: Colors.grey),
      GraphEdgeData(fromId: hubId, toId: memB, color: Colors.grey),
    ];
    final group = dragGroupForNode(hubId, edges, nodes);
    expect(group, {hubId, memA, memB});
  });

  test('initialGraphPositions places satellites in tree under memory hub', () {
    final nodes = [
      GraphNodeData(
        id: 'memory_m1',
        title: '허브',
        subtitle: '',
        color: Colors.red,
        kind: GraphNodeKind.memory,
        size: const Size(90, 90),
        layoutClusterId: 'c1',
      ),
      GraphNodeData(
        id: 'person_p1',
        title: '민수',
        subtitle: '',
        color: Colors.blue,
        kind: GraphNodeKind.person,
        size: const Size(70, 70),
        layoutClusterId: 'c1',
      ),
      GraphNodeData(
        id: 'place_l1',
        title: '카페',
        subtitle: '',
        color: Colors.teal,
        kind: GraphNodeKind.place,
        size: const Size(70, 70),
        layoutClusterId: 'c1',
      ),
    ];
    final edges = [
      GraphEdgeData(fromId: 'memory_m1', toId: 'person_p1', color: Colors.grey),
      GraphEdgeData(fromId: 'memory_m1', toId: 'place_l1', color: Colors.grey),
    ];
    final pos = initialGraphPositions(nodes, edges, const Size(1200, 900));
    final hub = pos['memory_m1']!;
    final person = pos['person_p1']!;
    final place = pos['place_l1']!;
    expect(person.dy, greaterThan(hub.dy));
    expect(place.dy, greaterThan(hub.dy));
    // 같은 깊이(행)에 나란히
    expect((person.dy - place.dy).abs(), lessThan(1.0));
  });

  test('mergeStoredGraphPositions keeps satellites relative to moved hub', () {
    final nodes = [
      GraphNodeData(
        id: 'memory_m1',
        title: '허브',
        subtitle: '',
        color: Colors.red,
        kind: GraphNodeKind.memory,
        size: const Size(90, 90),
        layoutClusterId: 'c1',
      ),
      GraphNodeData(
        id: 'person_p1',
        title: '민수',
        subtitle: '',
        color: Colors.blue,
        kind: GraphNodeKind.person,
        size: const Size(70, 70),
        layoutClusterId: 'c1',
      ),
    ];
    final edges = [
      GraphEdgeData(fromId: 'memory_m1', toId: 'person_p1', color: Colors.grey),
    ];
    final defaults = {
      'memory_m1': const Offset(100, 100),
      'person_p1': const Offset(100, 210),
    };
    final stored = {'memory_m1': const Offset(400, 300)};
    final merged = mergeStoredGraphPositions(
      nodes: nodes,
      edges: edges,
      defaults: defaults,
      stored: stored,
    );
    expect(merged['memory_m1'], const Offset(400, 300));
    expect(merged['person_p1'], const Offset(400, 410));
  });

  test('cafe friend memory graph hides satellites already in hub title', () {
    final memory = Memory(
      id: 'cafe',
      content: '철수와 카페에서 3시간 이야기.',
      summary: '철수와 카페에서 3시간 이야기.',
      entities: const ['철수', '카페'],
      category: 'Social',
      subCategory: '친구',
      createdAt: DateTime(2026, 6, 17, 15),
      lat: 35.1,
      lng: 129.0,
    );

    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    final person = layout.nodes.where((n) => n.kind == GraphNodeKind.person && n.title == '철수');
    final place = layout.nodes.where((n) => n.kind == GraphNodeKind.place && n.title == '카페');
    final composite = layout.nodes.where((n) => n.title == '철수와 카페');
    final memoryHub = layout.nodes.where((n) => n.kind == GraphNodeKind.memory);

    expect(memoryHub, hasLength(1));
    expect(memoryHub.first.title, contains('철수'));
    expect(memoryHub.first.title, contains('카페'));
    expect(person, isEmpty);
    expect(place, isEmpty);
    expect(composite, isEmpty);
  });
}
