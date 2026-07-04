import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/embedding_utils.dart';
import 'package:personal_cognitive/utils/semantic_search.dart';

void main() {
  test('searchMemoriesByEmbedding finds semantically similar memories', () {
    final query = [1.0, 0.0, 0.0];
    final cafe = Memory(
      id: '1',
      content: '카페에서 라떼',
      summary: '카페',
      entities: const ['카페'],
      createdAt: DateTime(2025, 1, 1),
      embedding: [0.95, 0.05, 0.0],
    );
    final unrelated = Memory(
      id: '2',
      content: '헬스장',
      summary: '운동',
      entities: const [],
      createdAt: DateTime(2025, 1, 2),
      embedding: [0.0, 1.0, 0.0],
    );

    final matches = searchMemoriesByEmbedding([cafe, unrelated], query);
    expect(matches, hasLength(1));
    expect(matches.first.id, '1');
    expect(cosineSimilarity(query, cafe.embedding!), greaterThan(0.9));
  });

  test('searchMemoriesHybrid merges keyword and embedding results', () {
    final memories = [
      Memory(
        id: 'a',
        content: '커피 한 잔',
        summary: '커피',
        entities: const ['커피'],
        createdAt: DateTime(2025, 1, 1),
      ),
      Memory(
        id: 'b',
        content: '카페에서 라떼',
        summary: '카페',
        entities: const ['카페'],
        createdAt: DateTime(2025, 1, 2),
        embedding: [0.9, 0.1],
      ),
    ];

    final matches = searchMemoriesHybrid(
      memories: memories,
      query: '커피',
      queryEmbedding: [1.0, 0.0],
    );
    expect(matches.map((m) => m.id), containsAll(['a', 'b']));
  });
}
