import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

Memory _mem(String content, {List<String> entities = const []}) {
  return Memory(
    id: '1',
    content: content,
    summary: content,
    entities: entities,
    createdAt: DateTime(2026, 7, 6),
  );
}

void main() {
  const text =
      '홍길동이 부산에서 커피를 마시며 스타트업과 인공지능 프로젝트에 대해 논의한 경험은 창의적인 아이디어와 협력의 중요성을 느끼게 해주었다.';

  test('인공지능·스타트업은 사람 이름으로 보지 않음', () {
    expect(isLikelyKoreanPersonName('인공지능'), isFalse);
    expect(isLikelyKoreanPersonName('스타트업'), isFalse);
    expect(isLikelyKoreanPersonName('홍길동'), isTrue);
  });

  test('스타트업과 패턴이 스타트업을 사람으로 추출하지 않음', () {
    final people = extractPeopleFromMemoryText(text);
    expect(people, contains('홍길동'));
    expect(people, isNot(contains('인공지능')));
    expect(people, isNot(contains('스타트업')));
  });

  test('entities에 인공지능이 있어도 사람 위성이 아님', () {
    final bundle = extractMemoryEntities(
      _mem(text, entities: ['홍길동', '인공지능', '부산', '스타트업']),
      localeCode: 'ko',
    );
    expect(bundle.people, contains('홍길동'));
    expect(bundle.people, isNot(contains('인공지능')));
    expect(bundle.people, isNot(contains('스타트업')));
    expect(bundle.interests, contains('인공지능'));
    expect(bundle.interests, contains('스타트업'));
  });

  test('반려견 이름은 사람이 아니라 반려견으로 분류', () {
    final bundle = extractMemoryEntities(
      _mem('노견 마루와 두부 산책 후 식사했다. 반려견 이름은 마루, 두부다.'),
      localeCode: 'ko',
    );
    expect(bundle.people, isNot(contains('마루')));
    expect(bundle.people, isNot(contains('두부')));
    expect(bundle.people, isNot(contains('노견')));
    expect(bundle.pets, contains('마루'));
    expect(bundle.pets, contains('두부'));
  });
}
