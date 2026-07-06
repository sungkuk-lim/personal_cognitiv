import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

Memory _mem(String content) {
  return Memory(
    id: 'corn_meal',
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: DateTime(2026, 7, 5),
    isLocalOnly: true,
  );
}

void main() {
  const text = '예린엄마와 아들과 옥수수를 삶아 먹었어';

  test('compound parent term extracted without bare 엄마', () {
    expect(isLikelyKoreanPersonName('옥수수'), isFalse);
    expect(extractCompoundParentTermsFromText(text), contains('예린엄마'));
    expect(extractFamilyRelationTermsFromText(text), contains('아들'));
    expect(extractFamilyRelationTermsFromText(text), isNot(contains('엄마')));
    expect(extractPeopleFromMemoryText(text), contains('예린엄마'));
    expect(extractPeopleFromMemoryText(text), contains('아들'));
    expect(extractPeopleFromMemoryText(text), isNot(contains('엄마')));
  });

  test('entities bundle has people and food not person-person activity', () {
    final bundle = extractMemoryEntities(_mem(text), localeCode: 'ko');
    expect(bundle.people, contains('예린엄마'));
    expect(bundle.people, contains('아들'));
    expect(bundle.people, isNot(contains('엄마')));
    expect(bundle.food, contains('옥수수'));
    expect(bundle.activities.any((a) => a.contains('와')), isFalse);
    expect(isPersonPlaceCompositeActivity('예린엄마와 아들'), isTrue);
  });

  test('visible satellites are yerin mom, son, corn', () {
    final memory = _mem(text);
    final visible = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(visible.people, containsAll(['예린엄마', '아들']));
    expect(visible.people, isNot(contains('엄마')));
    expect(visible.food, contains('옥수수'));
    expect(visible.activities, isEmpty);
  });

  test('graph layout shows hub plus three satellites', () {
    final layout = buildMemoryGraphLayout(
      [_mem(text)],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    final satellites = layout.nodes.where((n) => n.kind != GraphNodeKind.memory).toList();
    expect(satellites, hasLength(3));
    expect(
      satellites.where((n) => n.kind == GraphNodeKind.person).map((n) => n.title).toList(),
      containsAll(['예린엄마', '아들']),
    );
    expect(satellites.where((n) => n.title == '엄마'), isEmpty);
    expect(satellites.where((n) => n.kind == GraphNodeKind.food).single.title, '옥수수');
    expect(satellites.where((n) => n.kind == GraphNodeKind.person && n.title == '옥수수'), isEmpty);
    expect(layout.nodes.where((n) => n.title == '나'), isEmpty);
    expect(
      layout.nodes.any((n) => n.kind == GraphNodeKind.activity && n.title.contains('와')),
      isFalse,
    );
  });
}
