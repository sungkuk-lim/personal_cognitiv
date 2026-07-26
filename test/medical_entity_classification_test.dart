import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/medical_entity_lexicon.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_keyword_ui.dart';

Memory _memory(String content) => Memory(
      id: 't',
      content: content,
      summary: '',
      entities: const [],
      createdAt: DateTime(2026, 7, 9),
    );

void main() {
  const clinic =
      '오늘 대성그린병원 외진현황 보고로는 총 7명이 외진했습니다. '
      '성소병원에는 이정숙 환자를 정형외과, 김명희 환자를 안과, 정준호 환자, 이기동 환자는 치과로 진료했습니다. '
      '안동병원에는 기우대 환자는 소화기내과로 진료했습니다.';

  test('정형외과 particle strip does not truncate to person name', () {
    expect(stripTrailingKoreanParticles('정형외과'), '정형외과');
    expect(normalizeKoreanPersonName('정형외과'), '정형외과');
    expect(isLikelyKoreanPersonName('정형외과'), isFalse);
    expect(isLikelyKoreanPersonName('정형외'), isFalse);
  });

  test('안과 is place-like not person', () {
    expect(isMedicalDepartmentLabel('안과'), isTrue);
    expect(isLikelyKoreanPersonName('안과'), isFalse);
    expect(classifyKeyword('안과', _memory(clinic)), MemoryKeywordKind.place);
  });

  test('hospitals extracted as places not phrase garbage', () {
    final bundle = extractMemoryEntities(_memory(clinic));
    expect(bundle.places, contains('안동병원'));
    expect(bundle.places, contains('성소병원'));
    expect(bundle.places, contains('정형외과'));
    expect(bundle.people, containsAll(['정준호', '김명희', '이기동', '이정숙']));
    expect(bundle.places, isNot(contains('정준호')));
    expect(bundle.places, isNot(contains('김명희')));
    expect(bundle.places, isNot(contains('이기동')));
    expect(bundle.people, isNot(contains('안과')));
    expect(bundle.people, isNot(contains('정형외')));
    expect(bundle.people, isNot(contains('환자')));
    expect(bundle.places.any((p) => p.contains('외진현황')), isFalse);
    expect(bundle.places.any((p) => p.contains('환자는')), isFalse);
  });

  test('classifyKeyword keeps patient names as person', () {
    expect(classifyKeyword('정준호', _memory(clinic)), MemoryKeywordKind.person);
    expect(classifyKeyword('김명희', _memory(clinic)), MemoryKeywordKind.person);
    expect(classifyKeyword('이기동', _memory(clinic)), MemoryKeywordKind.person);
  });

  test('classifyKeyword maps medical facilities to place', () {
    expect(classifyKeyword('안동병원', _memory(clinic)), MemoryKeywordKind.place);
    expect(classifyKeyword('정형외과', _memory(clinic)), MemoryKeywordKind.place);
    expect(classifyKeyword('외진현황으로', _memory(clinic)), MemoryKeywordKind.tag);
  });
}
