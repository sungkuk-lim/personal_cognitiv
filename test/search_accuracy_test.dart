import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/local_memory_store.dart';
import 'package:personal_cognitive/utils/memory_keyword_ui.dart';

void main() {
  final gilancheon = Memory(
    id: 'gilancheon',
    content: '아버지, 어머니, 나, 집사람, 예린이, 태민이 길안천 나들이',
    summary: '길안천 나들이',
    entities: const ['집사람', '태민', '길안천'],
    createdAt: DateTime(2026, 6, 22),
    isLocalOnly: true,
  );
  final work = Memory(
    id: 'work',
    content: '회사에서 프로젝트 회의',
    summary: '회의',
    entities: const ['민수'],
    createdAt: DateTime(2026, 6, 1),
    isLocalOnly: true,
  );
  final spouseOnly = Memory(
    id: 'dinner',
    content: '집사람과 저녁 식사',
    summary: '저녁',
    entities: const ['집사람'],
    createdAt: DateTime(2026, 6, 20),
    isLocalOnly: true,
  );

  test('집사람 검색은 엔티티 기반 기억만, 태민 본문만 언급은 제외', () {
    final taeminMention = Memory(
      id: 'trip',
      content: '태민이랑 놀이터',
      summary: '놀이',
      entities: const ['예린'],
      createdAt: DateTime(2026, 6, 21),
      isLocalOnly: true,
    );
    expect(memoryMatchesKeyword(gilancheon, '집사람'), isTrue);
    expect(memoryMatchesKeyword(taeminMention, '집사람'), isFalse);
    expect(memoryMatchesKeyword(taeminMention, '태민'), isTrue);
  });

  test('searchLocalMemories ranks entity match above body mention', () {
    final bodyOnly = Memory(
      id: 'body',
      content: '오늘 집사람 이야기를 들었다',
      summary: '이야기',
      entities: const ['민수'],
      createdAt: DateTime(2026, 6, 23),
      isLocalOnly: true,
    );
    final results = searchLocalMemories([bodyOnly, spouseOnly, gilancheon], '집사람');
    expect(memoryKeywordMatchScore(results.first, '집사람'), greaterThan(memoryKeywordMatchScore(bodyOnly, '집사람')));
    expect(results.last.id, bodyOnly.id);
    expect(results.map((m) => m.id), isNot(contains(work.id)));
  });

  test('장소 키워드는 엔티티·장소 후보로 매칭', () {
    expect(memoryMatchesKeyword(gilancheon, '길안천'), isTrue);
    expect(memoryKeywordMatchScore(gilancheon, '길안천'), greaterThanOrEqualTo(90));
    expect(memoryMatchesKeyword(work, '길안천'), isFalse);
  });
}
