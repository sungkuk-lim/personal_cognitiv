import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/entity_canonical.dart';
import 'package:personal_cognitive/utils/graph_entity_quality.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  group('인명 정규화', () {
    test('조사·호칭·직함 제거', () {
      expect(normalizeKoreanPersonName('홍길동이'), '홍길동');
      expect(normalizeKoreanPersonName('홍길동은'), '홍길동');
      expect(normalizeKoreanPersonName('홍길동과'), '홍길동');
      expect(normalizeKoreanPersonName('홍길동 교수'), '홍길동');
      expect(normalizeKoreanPersonName('이재용 회장'), '이재용');
      expect(normalizeKoreanPersonName('삼성 이재용'), '이재용');
    });
  });

  group('별칭·약어 통합', () {
    test('AI·OpenAI·띄어쓰기', () {
      expect(canonicalEntityLabel('인공지능'), 'AI');
      expect(canonicalEntityLabel('artificial intelligence'), 'AI');
      expect(canonicalEntityLabel('오픈AI'), 'OpenAI');
      expect(normalizeGraphEntityLabel('서울 대학교'), '서울대학교');
    });
  });

  group('기관·장소 추출', () {
    test('복합명사 유지', () {
      const text = '국민건강보험공단에서 서울대학교병원으로 이송';
      expect(extractQualityOrganizations(text), contains('국민건강보험공단'));
      expect(extractQualityOrganizations(text), contains('서울대학교병원'));
    });

    test('도시·회사', () {
      const text = '홍길동이 부산에서 삼성전자 회의';
      expect(extractQualityPlaces(text), contains('부산'));
      expect(extractQualityOrganizations(text), contains('삼성전자'));
    });
  });

  group('관계·부정문', () {
    test('부정문이면 방문 관계 생략', () {
      final memory = Memory(
        id: '1',
        content: '부산을 방문하지 않았다',
        summary: '',
        entities: const [],
        createdAt: DateTime(2026, 7, 6),
      );
      final rels = extractRelationsFromMemory(memory, localeCode: 'ko');
      expect(rels.where((r) => r.predicate == '방문'), isEmpty);
    });

    test('부정문 감지', () {
      expect(isNegatedRelationContext('부산을 방문하지 않았다', '방문'), isTrue);
      expect(isNegatedRelationContext('나는 AI를 좋아한다', '좋아하'), isFalse);
    });
  });

  group('언급 횟수', () {
    test('mentionCountInText', () {
      expect(mentionCountInText('홍길동', '홍길동과 홍길동이 만났다'), 2);
    });
  });
}
