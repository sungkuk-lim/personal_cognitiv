import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

const petStory = '''나는 2015년에 첫째 반려견 마루를 입양했다.
2018년에 두부를 입양했고 마루는 두부를 잘 돌봐주었다.
2021년에 만두를 데려왔는데 두부는 질투가 많아서 처음에는 만두를 싫어했다.
하지만 몇 달 후에는 셋이 항상 같이 산책을 다녔다.
2024년에 마루가 노견이 되면서 산책 시간이 줄어들었고 나는 매일 저녁 공원에서 마루를 안고 걸었다.''';

Memory _petMemory() => Memory(
      id: 'pet_story',
      content: petStory,
      summary: '',
      entities: const [],
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  test('pet story extracts maru dubu mandu as pets not people', () {
    final bundle = extractMemoryEntities(_petMemory(), localeCode: 'ko');
    expect(bundle.pets, containsAll(['마루', '두부', '만두']));
    expect(bundle.people, isNot(contains('노견')));
    expect(bundle.people, isNot(contains('첫째')));
    expect(bundle.people, isNot(contains('마루')));
    expect(bundle.interests, isNot(contains('반려견')));
    expect(bundle.interests, isNot(contains('첫째')));
    expect(bundle.activities, contains('산책'));
  });

  test('pet story graph shows pet satellites with 반려견 label', () {
    final visible = visibleGraphSatellitesForMemory(_petMemory(), localeCode: 'ko');
    expect(visible.pets, containsAll(['마루', '두부', '만두']));
    expect(visible.people, isNot(contains('노견')));

    final layout = buildMemoryFocusGraphLayout(_petMemory(), localeCode: 'ko');
    final petNodes = layout.layout.nodes.where((n) => n.kind == GraphNodeKind.pet).toList();
    expect(petNodes.map((n) => n.title), containsAll(['마루', '두부', '만두']));
    expect(petNodes.first.subtitle, '반려견');
  });

  test('노견 and 첫째 are not person names', () {
    expect(isLikelyKoreanPersonName('노견'), isFalse);
    expect(isPetOrdinalToken('첫째'), isTrue);
    expect(extractPetNamesFromText('첫째 반려견 마루를 입양'), ['마루']);
  });
}
