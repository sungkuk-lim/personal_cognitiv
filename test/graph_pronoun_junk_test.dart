import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

void main() {
  test('둘은 is not a person', () {
    expect(isKoreanPronounWithParticle('둘은'), isTrue);
    expect(isGraphMorphologyJunkToken('둘은'), isTrue);
    expect(isLikelyKoreanPersonName('둘은'), isFalse);
    const text =
        '민수는 네이버에서 일하는 지영의 남동생이며, 둘은 토요일마다 성수동의 카페에서 커피를 마시고 보드게임을 즐긴다.';
    expect(extractPeopleFromMemoryText(text), isNot(contains('둘은')));
    expect(extractPeopleFromMemoryText(text), isNot(contains('둘')));
  });
}
