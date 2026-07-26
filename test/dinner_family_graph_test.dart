import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

const dinner = '''저녁식사 시간에 집사람과 자담치킨 한마리 시켜놓고 맥주 한 잔했다
아들이 온다고했는데 자고 있는가 보다
딸 한테도 전화가왔다
지금 이런게 행복일거다''';

Memory _dinnerMemory({List<String> entities = const []}) => Memory(
      id: 'dinner',
      content: dinner,
      summary: '',
      entities: entities,
      createdAt: DateTime(2025, 7, 7),
    );

void main() {
  test('집사람 아들 딸 are people, 저녁 and 행복 are not', () {
    expect(isLikelyKoreanPersonName('저녁'), isFalse);
    expect(isLikelyKoreanPersonName('행복'), isFalse);
    expect(isLikelyKoreanPersonName('집사람'), isTrue);

    final bundle = extractMemoryEntities(_dinnerMemory(), localeCode: 'ko');
    expect(bundle.people, containsAll(['집사람', '아들', '딸']));
    expect(bundle.people, isNot(contains('저녁')));
    expect(bundle.people, isNot(contains('행복')));
    expect(bundle.emotions, contains('행복'));
  });

  test('stored 저녁 entity does not become person satellite', () {
    final memory = _dinnerMemory(entities: ['집사람', '아들', '딸', '행복', '저녁']);
    final vis = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(vis.people, containsAll(['집사람', '아들', '딸']));
    expect(vis.people, isNot(contains('저녁')));
    expect(vis.people, isNot(contains('행복')));
    expect(vis.emotions, contains('행복'));
    expect(vis.activities, isNot(contains('저녁')));
  });

  test('dinner memory graph has family and emotion satellites only', () {
    final layout = buildMemoryFocusGraphLayout(_dinnerMemory(), localeCode: 'ko');
    final people = layout.layout.nodes.where((n) => n.kind == GraphNodeKind.person).map((n) => n.title).toList();
    expect(people, containsAll(['집사람', '아들', '딸']));
    expect(people, isNot(contains('저녁')));
    expect(layout.layout.nodes.any((n) => n.title == '행복' && n.kind == GraphNodeKind.emotion), isTrue);
  });
}
