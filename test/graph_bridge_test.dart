import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('cross-cluster hub bridges connect groups sharing a person', () {
    final memories = [
      Memory(
        id: 'a1',
        content: '민수와 강남에서 점심을 먹었다',
        summary: '민수와 강남 점심',
        entities: const ['민수', '강남'],
        createdAt: DateTime(2026, 5, 1, 12),
        lat: 37.5,
        lng: 127.0,
      ),
      Memory(
        id: 'a2',
        content: '민수와 카페에서 대화',
        summary: '민수와 카페',
        entities: const ['민수'],
        createdAt: DateTime(2026, 5, 1, 15),
        lat: 37.5,
        lng: 127.0,
      ),
      Memory(
        id: 'b1',
        content: '민수와 영화를 봤다',
        summary: '민수와 영화',
        entities: const ['민수'],
        createdAt: DateTime(2026, 5, 3, 20),
        lat: 37.6,
        lng: 127.1,
      ),
      Memory(
        id: 'b2',
        content: '민수에게 연락',
        summary: '민수 연락',
        entities: const ['민수'],
        createdAt: DateTime(2026, 5, 3, 22),
        lat: 37.6,
        lng: 127.1,
      ),
    ];

    final layout = buildMemoryGraphLayout(memories, localeCode: 'ko');
    final bridge = layout.edges.where((e) => e.bridgeLink).toList();
    expect(bridge, isNotEmpty);
    expect(
      bridge.any((e) => e.fromId.startsWith('group_') && e.toId.startsWith('group_')),
      isTrue,
    );
  });

  test('shared satellite node links memories across clusters when expanded', () {
    final memories = [
      Memory(
        id: 'a',
        content: '아들과 공원에서 놀았다',
        summary: '아들과 공원에서 놀았다',
        entities: const ['아들'],
        createdAt: DateTime(2026, 5, 1, 10),
        lat: 35.1,
        lng: 128.9,
      ),
      Memory(
        id: 'b',
        content: '아들 학교 상담',
        summary: '아들 학교 상담',
        entities: const ['아들'],
        createdAt: DateTime(2026, 5, 2, 10),
        lat: 35.2,
        lng: 129.0,
      ),
    ];

    final layout = buildMemoryGraphLayout(
      memories,
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );
    final personNodes = layout.nodes.where((n) => n.kind == GraphNodeKind.person).toList();
    expect(personNodes.length, 1);
    final personId = personNodes.first.id;
    final memoryAnchors = {'memory_a', 'memory_b'};
    final links = layout.edges.where(
      (e) => e.toId == personId && memoryAnchors.contains(e.fromId),
    );
    expect(links.length, greaterThanOrEqualTo(2));
  });
}
