import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_query.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';

Memory _memory({
  required String id,
  required String content,
  List<String> entities = const [],
  String type = 'text',
  String subCategory = '',
}) {
  return Memory(
    id: id,
    userId: 'u1',
    content: content,
    summary: content,
    type: type,
    subCategory: subCategory,
    entities: entities,
    createdAt: DateTime(2025, 6, 1),
    isLocalOnly: true,
  );
}

void main() {
  group('parseNaturalLanguageQuery', () {
    test('어머니 행복 식사 — 인물·감정·활동', () {
      final q = parseNaturalLanguageQuery('어머니와 행복한 식사', localeCode: 'ko');
      expect(q.people, contains('어머니'));
      expect(q.emotions, contains('행복'));
      expect(q.activities, contains('식사'));
      expect(q.isComposite, isTrue);
    });

    test('광안리 사진 — 장소·사진', () {
      final q = parseNaturalLanguageQuery('광안리해수욕장 사진', localeCode: 'ko');
      expect(q.places.any((p) => p.contains('광안리')), isTrue);
      expect(q.hasPhoto, isTrue);
      expect(q.isComposite, isTrue);
    });

    test('인공지능·스타트업 — 관심사 (사람 아님)', () {
      final q = parseNaturalLanguageQuery(
        '홍길동이 부산에서 스타트업과 인공지능 프로젝트 논의',
        localeCode: 'ko',
      );
      expect(q.interests, contains('인공지능'));
      expect(q.interests, contains('스타트업'));
      expect(q.people, contains('홍길동'));
      expect(q.people, isNot(contains('인공지능')));
      expect(q.people, isNot(contains('스타트업')));
    });
  });

  group('filterMemoriesByQuery', () {
    test('AND 조건 — 어머니 + 행복 + 식사', () {
      final memories = [
        _memory(
          id: '1',
          content: '어머니와 행복한 저녁 식사',
          entities: ['tag:emotion:행복', 'tag:activity:식사', '어머니'],
        ),
        _memory(id: '2', content: '어머니와 산책'),
        _memory(id: '3', content: '행복한 식사 혼자'),
      ];

      final q = parseNaturalLanguageQuery('어머니 행복 식사', localeCode: 'ko');
      final matched = filterMemoriesByQuery(memories, q, localeCode: 'ko');
      expect(matched.length, 1);
      expect(matched.first.id, '1');
    });

    test('사진 필터', () {
      final memories = [
        _memory(id: 'a', content: '바다', type: 'image'),
        _memory(id: 'b', content: '바다'),
      ];
      final q = const MemoryQuery(hasPhoto: true);
      final matched = filterMemoriesByQuery(memories, q, localeCode: 'ko');
      expect(matched.map((m) => m.id), ['a']);
    });
  });

  group('enrichMemoryGraphSemantics', () {
    test('본문에서 감정·음식 태그 자동 부여', () {
      final raw = _memory(id: 'x', content: '행복한 저녁에 치킨 먹었다');
      final enriched = enrichMemoryGraphSemantics(raw, localeCode: 'ko');
      expect(enriched.entities, contains('tag:emotion:행복'));
      expect(enriched.entities, contains('tag:food:치킨'));
    });
  });
}
