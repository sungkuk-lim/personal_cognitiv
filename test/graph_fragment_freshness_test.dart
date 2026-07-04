import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/graph_ai_snapshot.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_fragment_freshness.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

void main() {
  final memory = Memory(
    id: 'm1',
    content: '영희와 카페에서 3시간 이야기',
    summary: '영희와 카페에서 3시간 이야기',
    entities: const ['영희', '카페'],
    createdAt: DateTime(2026, 7, 3),
  );

  test('stale fragment is ignored after edit', () {
    const stale = GraphMemoryFragment(
      meaningTitle: '철수와 카페에서 3시간 이야기',
      satellites: [
        GraphAiSatellite(kind: 'person', label: '철수'),
        GraphAiSatellite(kind: 'place', label: '카페'),
      ],
    );
    expect(isGraphFragmentStaleForMemory(memory, stale), isTrue);
    final bundle = extractMemoryEntities(memory, aiFragment: stale);
    expect(bundle.people, isNot(contains('철수')));
    expect(bundle.people, contains('영희'));
  });

  test('shouldShowGraphSatelliteLabel hides place in hub title', () {
    expect(
      shouldShowGraphSatelliteLabel('카페', hubTitle: '영희와 카페에서 3시간 이야기'),
      isFalse,
    );
    expect(
      shouldShowGraphSatelliteLabel('영희', hubTitle: '영희와 카페에서 3시간 이야기'),
      isFalse,
    );
    expect(
      shouldShowGraphSatelliteLabel('아들', hubTitle: '아들과 집에서 저녁식사 함께함'),
      isTrue,
    );
  });

  test('entityLabelReferencedInMemory drops stale names after edit', () {
    final memory = Memory(
      id: 'm1',
      content: '영희와 카페에서 3시간 이야기',
      summary: '영희와 카페에서 3시간 이야기',
      entities: const ['철수', '영희', '카페'],
      createdAt: DateTime(2026, 7, 3),
    );
    expect(entityLabelReferencedInMemory('철수', memory), isFalse);
    expect(entityLabelReferencedInMemory('영희', memory), isTrue);
    expect(entityLabelReferencedInMemory('카페', memory), isTrue);
  });

  test('edited memory graph drops stale person and duplicate place', () {
    const stale = GraphMemoryFragment(
      meaningTitle: '철수와 카페에서 3시간 이야기',
      satellites: [
        GraphAiSatellite(kind: 'person', label: '철수'),
        GraphAiSatellite(kind: 'place', label: '카페'),
      ],
    );
    final layout = buildMemoryGraphLayout(
      [memory],
      graphFragments: {'m1': stale},
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    expect(
      layout.nodes.where((n) => n.kind == GraphNodeKind.memory).map((n) => n.title).first,
      contains('영희'),
    );
    expect(layout.nodes.where((n) => n.title == '철수'), isEmpty);
    expect(layout.nodes.where((n) => n.kind == GraphNodeKind.place && n.title == '카페'), isEmpty);

    final hub = layout.nodes.firstWhere((n) => n.id == 'memory_m1');
    expect(hub.satelliteBadge, isNull);
  });

  test('son dinner memory keeps son satellite and matching badge', () {
    final memory = Memory(
      id: 'dinner',
      content: '아들과 집에서 저녁식사 함께함',
      summary: '아들과 집에서 저녁식사 함께함',
      entities: const ['아들'],
      createdAt: DateTime(2026, 7, 3),
    );
    final visible = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(visible.people, contains('아들'));
    expect(visible.places, isEmpty);

    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );
    expect(
      layout.nodes.where((n) => n.kind == GraphNodeKind.person && n.title == '아들'),
      hasLength(1),
    );
    final hub = layout.nodes.firstWhere((n) => n.id == 'memory_dinner');
    expect(hub.satelliteBadge, contains('사람 1'));
  });
}
