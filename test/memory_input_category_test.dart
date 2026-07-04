import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/graph_ai_snapshot.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/graph_query_engine.dart';
import 'package:personal_cognitive/utils/memory_input_category.dart';

Memory _memory({
  required String id,
  required String content,
  List<String> entities = const [],
  String subCategory = '',
  DateTime? createdAt,
}) {
  return Memory(
    id: id,
    content: content,
    summary: content,
    entities: entities,
    subCategory: subCategory,
    createdAt: createdAt ?? DateTime(2025, 6, 10),
    type: 'voice',
    category: 'Social',
  );
}

void main() {
  test('applyMemoryInputCategory overrides subCategory', () {
    final applied = applyMemoryInputCategory(
      localeCode: 'ko',
      inputCategory: memoryInputCategories.first,
      fallbackCategory: 'Other',
      fallbackSubCategory: '일상',
    );
    expect(applied.category, 'Social');
    expect(applied.subCategory, '가족');
  });

  test('category count query from graph DB', () {
    final memories = [
      _memory(id: '1', content: '친구와 점심', subCategory: '친구'),
      _memory(id: '2', content: '친구 모임', subCategory: '친구'),
    ];
    final answer = tryAnswerFromGraphDb(
      query: '친구 관련 기록 몇 건?',
      memories: memories,
      fragments: const {},
      localeCode: 'ko',
    );
    expect(answer, isNotNull);
    expect(answer!.text, contains('2'));
  });

  test('together query finds memories with shared person context', () {
    final memories = [
      _memory(id: '1', content: '어머니와 광안리', entities: ['어머니', '광안리']),
      _memory(id: '2', content: '어머니 집', entities: ['어머니']),
    ];
    final answer = tryAnswerFromGraphDb(
      query: '어머니 관련 몇 건?',
      memories: memories,
      fragments: const {},
      localeCode: 'ko',
    );
    expect(answer, isNotNull);
    expect(answer!.relatedMemories.length, greaterThanOrEqualTo(2));
  });
}
