import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

Memory _mem(String id, String content) => Memory(
      id: id,
      content: content,
      summary: content,
      entities: const [],
      createdAt: DateTime(2026, 7, 5),
    );

List<String> _nodeTitles(GraphLayout layout, GraphNodeKind kind) =>
    layout.nodes.where((n) => n.kind == kind).map((n) => n.title).toList();

void main() {
  group('morphology junk must not become nodes', () {
    const harry =
        '지영은 독서 모임에서 만난 민수에게 『해리 포터』를 추천받았고, 둘은 다음 달 부산국제영화제에 함께 가기로 했다';

    test('harry potter sentence', () {
      final m = _mem('harry', harry);
      final bundle = extractMemoryEntities(m, localeCode: 'ko');
      final visible = visibleGraphSatellitesForMemory(m, localeCode: 'ko');
      final layout = buildMemoryGraphLayout([m], localeCode: 'ko', collapseSatellitesByDefault: false);

      const junk = ['천받았고', '둘은', '를 추천', '둘', '추천'];
      for (final j in junk) {
        expect(bundle.people, isNot(contains(j)), reason: 'people');
        expect(bundle.places, isNot(contains(j)), reason: 'places');
        expect(visible.people, isNot(contains(j)));
        expect(visible.places, isNot(contains(j)));
        expect(layout.nodes.map((n) => n.title), isNot(contains(j)));
      }

      expect(bundle.people, containsAll(['지영', '민수']));
      expect(bundle.eventTitle, isNot(contains('기억에 남는')));
      expect(bundle.eventTitle, anyOf(contains('해리 포터'), contains('부산국제영화제'), contains('독서')));
      expect(visible.hobbies, contains('독서'));
    });
  });

  group('natural language stress cases', () {
    final cases = <({String id, String text, List<String> expectPeople, List<String> forbid, List<String> hubHints})>[
      (
        id: 'siblings_cafe',
        text: '민수는 네이버에서 일하는 지영의 남동생이며, 둘은 토요일마다 성수동의 카페에서 커피를 마시고 보드게임을 즐긴다.',
        expectPeople: ['민수', '지영'],
        forbid: ['천받았고', '둘은', '동생이며', '를 추천'],
        hubHints: ['성수동', '카페', '보드게임', '커피'],
      ),
      (
        id: 'euljiro_outing',
        text: '나는 어제 철수와 을지로에서 삼겹살을 먹은 후 영희를 만나 공연을 봤고, 공연이 끝난 뒤 함께 한강공원을 산책했다.',
        expectPeople: ['철수', '영희'],
        forbid: ['천받았고', '둘은', '를 추천', '삶아 먹음'],
        hubHints: ['삼겹살', '공연', '산책'],
      ),
      (
        id: 'seongsu_pizza',
        text: '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.',
        expectPeople: ['민수'],
        forbid: ['천받았고', '삶아 먹음'],
        hubHints: ['피자', '영화', '카페', '성수동'],
      ),
      (
        id: 'samsung_work',
        text: '민수와 지영은 삼성전자에서 함께 일한다',
        expectPeople: ['민수', '지영'],
        forbid: ['천받았고', '둘은'],
        hubHints: ['삼성전자', '근무'],
      ),
      (
        id: 'family_exam',
        text: '아들이 오늘 컴퓨터 활용 능력 1급 시험을 보러 갔는데 긴장을 많이 했다.',
        expectPeople: ['아들'],
        forbid: ['천받았고', '컴퓨터'],
        hubHints: ['시험'],
      ),
      (
        id: 'triple_relation',
        text: '철수는 민수의 대학 동기이고, 둘은 지영과 함께 스타트업을 창업했다.',
        expectPeople: ['철수', '민수', '지영'],
        forbid: ['천받았고', '둘은', '동기이고'],
        hubHints: ['스타트업', '창업'],
      ),
    ];

    for (final c in cases) {
      test(c.id, () {
        final m = _mem(c.id, c.text);
        final bundle = extractMemoryEntities(m, localeCode: 'ko');
        final layout = buildMemoryGraphLayout([m], localeCode: 'ko', collapseSatellitesByDefault: false);
        final allTitles = layout.nodes.map((n) => n.title).toList();

        for (final p in c.expectPeople) {
          expect(bundle.people, contains(p), reason: 'bundle people');
          final personNodes = _nodeTitles(layout, GraphNodeKind.person);
          if (personNodes.isNotEmpty) {
            expect(personNodes, contains(p), reason: 'person node');
          }
        }
        for (final bad in c.forbid) {
          expect(allTitles, isNot(contains(bad)), reason: 'forbid $bad');
        }
        expect(bundle.eventTitle, isNot(contains('기억에 남는')));
        expect(
          c.hubHints.any((h) => bundle.eventTitle.contains(h)),
          isTrue,
          reason: 'hub ${bundle.eventTitle}',
        );
      });
    }
  });
}
