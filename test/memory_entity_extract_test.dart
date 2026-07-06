import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/korean_person_names.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_semantic_extract.dart';

Memory _mem(String content) {
  return Memory(
    id: '1',
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: DateTime(2026, 7, 5),
    isLocalOnly: true,
  );
}

void main() {
  test('extractFamilyRelationTermsFromText finds 아들 from 아들이', () {
    const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대 잘 쳤으면 좋겠어';
    expect(extractFamilyRelationTermsFromText(text), contains('아들'));
  });

  test('extractPeopleFromMemoryText includes 아들', () {
    const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대 잘 쳤으면 좋겠어';
    expect(extractPeopleFromMemoryText(text), contains('아들'));
  });

  test('extractMemoryEntities includes 나 and 아들 with exam event', () {
    const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대 잘 쳤으면 좋겠어';
    final bundle = extractMemoryEntities(_mem(text), localeCode: 'ko');

    expect(bundle.people, contains('나'));
    expect(bundle.people, contains('아들'));
    expect(bundle.events.any((e) => e.contains('시험')), isTrue);
    expect(bundle.interests, isEmpty);
    expect(bundle.activities, isEmpty);
  });

  test('extractSemanticFromText picks exam event without duplicate categories', () {
    const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대';
    final scan = extractSemanticFromText(text);

    expect(scan.events.single, contains('시험'));
    expect(scan.events.single, contains('컴퓨터'));
    expect(scan.interests, isEmpty);
    expect(scan.activities, isEmpty);
  });

  test('userVisibleEntityLabels shows 아들 and exam-related tags', () {
    const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대 잘 쳤으면 좋겠어';
    final labels = userVisibleEntityLabels(_mem(text), localeCode: 'ko');

    expect(labels, contains('아들'));
    expect(labels, contains('나'));
    expect(labels.any((l) => l.contains('시험')), isTrue);
  });
}
