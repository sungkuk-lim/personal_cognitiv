import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_meaning.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

Memory _m(String content) => Memory(
      id: 't',
      content: content,
      summary: content,
      entities: const [],
      createdAt: DateTime(2026, 7, 5),
    );

void main() {
  test('naver siblings cafe boardgame', () {
    const text =
        '민수는 네이버에서 일하는 지영의 남동생이며, 둘은 토요일마다 성수동의 카페에서 커피를 마시고 보드게임을 즐긴다.';
    final title = graphMeaningSentence(_m(text), localeCode: 'ko');
    expect(title, isNot(contains('기억에 남는')));
    expect(title, anyOf(contains('성수동'), contains('카페'), contains('보드게임'), contains('커피')));
  });

  test('euljiro samgyeopsal performance walk', () {
    const text =
        '나는 어제 철수와 을지로에서 삼겹살을 먹은 후 영희를 만나 공연을 봤고, 공연이 끝난 뒤 함께 한강공원을 산책했다.';
    final title = graphMeaningSentence(_m(text), localeCode: 'ko');
    expect(title, isNot(contains('삶아 먹음')));
    expect(title, isNot(contains('기억에 남는')));
    expect(title, anyOf(contains('삼겹살'), contains('공연'), contains('산책')));
  });

  test('harry potter busan film festival', () {
    const text =
        '지영은 독서 모임에서 만난 민수에게 『해리 포터』를 추천받았고, 둘은 다음 달 부산국제영화제에 함께 가기로 했다.';
    final title = graphMeaningSentence(_m(text), localeCode: 'ko');
    expect(title, isNot(contains('기억에 남는')));
    expect(title, anyOf(contains('해리 포터'), contains('부산국제영화제'), contains('독서')));
  });

  test('seongsu pizza movie cafe outing', () {
    const text = '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.';
    final title = graphMeaningSentence(_m(text), localeCode: 'ko');
    expect(title, isNot(contains('삶아 먹음')));
    expect(title, anyOf(contains('피자'), contains('영화'), contains('카페'), contains('성수동')));
  });

  test('composeMemoryHubTitle joins key signals', () {
    expect(
      composeMemoryHubTitle('어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.', localeCode: 'ko'),
      '성수동·피자·영화·카페.',
    );
  });

  test('stale summary does not win over composed hub title', () {
    const text = '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.';
    final stale = Memory(
      id: 't',
      content: text,
      summary: '피자 삶아 먹음',
      entities: const [],
      createdAt: DateTime(2026, 7, 5),
    );
    final hub = extractMemoryEntities(stale, localeCode: 'ko').eventTitle;
    expect(hub, isNot(contains('삶아 먹음')));
    expect(hub, '성수동·피자·영화·카페.');
  });

  test('inferHubTitleFromContent for voice save', () {
    const text = '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.';
    expect(inferHubTitleFromContent(text), '성수동·피자·영화·카페');
    expect(inferHubTitleFromContent(text), isNot(contains('삶아 먹음')));
  });

  test('isFalseBoiledMealHubTitle catches stale meal summary', () {
    const text = '어제 민수와 성수동에서 피자를 먹고 영화를 본 뒤 카페에 갔다.';
    expect(isFalseBoiledMealHubTitle('피자 삶아 먹음', text), isTrue);
    expect(isFalseBoiledMealHubTitle('옥수수 삶아 먹음', '옥수수를 삶아 먹었어'), isFalse);
  });
}
