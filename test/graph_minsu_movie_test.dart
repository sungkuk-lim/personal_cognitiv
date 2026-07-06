import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_semantic_extract.dart';

Memory _mem(String content) {
  return Memory(
    id: 'seongsu_outing',
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: DateTime(2026, 7, 4),
    isLocalOnly: true,
  );
}

void main() {
  const text = '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다';

  test('영화 is content not person', () {
    expect(isLikelyKoreanPersonName('영화'), isFalse);
    expect(isKnownContentLabel('영화'), isTrue);
    final scan = extractSemanticFromText(text);
    expect(scan.contents, contains('영화'));
    expect(scan.hobbies, isNot(contains('영화')));
  });

  test('bundle has minsu, seongsu, pizza, movie content only once', () {
    final bundle = extractMemoryEntities(_mem(text), localeCode: 'ko');
    expect(bundle.people, contains('민수'));
    expect(bundle.people, isNot(contains('영화')));
    expect(bundle.places, contains('성수동'));
    expect(bundle.places, contains('카페'));
    expect(bundle.food, contains('피자'));
    expect(bundle.contents, contains('영화'));
    expect(bundle.hobbies, isNot(contains('영화')));
  });

  test('graph has single 영화 node as content', () {
    final layout = buildMemoryGraphLayout(
      [_mem(text)],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    final movieNodes = layout.nodes.where((n) => n.title == '영화').toList();
    expect(movieNodes, hasLength(1));
    expect(movieNodes.single.kind, GraphNodeKind.content);

    expect(layout.nodes.where((n) => n.title == '민수' && n.kind == GraphNodeKind.person), hasLength(1));
    expect(layout.nodes.where((n) => n.title == '성수동' && n.kind == GraphNodeKind.place), hasLength(1));
    expect(layout.nodes.where((n) => n.title == '카페' && n.kind == GraphNodeKind.place), hasLength(1));
    expect(layout.nodes.where((n) => n.title == '피자' && n.kind == GraphNodeKind.food), hasLength(1));
  });

  test('visible satellites dedupe movie category', () {
    final visible = visibleGraphSatellitesForMemory(_mem(text), localeCode: 'ko');
    expect(visible.contents, contains('영화'));
    expect(visible.hobbies, isNot(contains('영화')));
    expect(visible.people, isNot(contains('영화')));
  });
}
