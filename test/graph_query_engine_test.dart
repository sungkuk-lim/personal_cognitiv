import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/graph_ai_snapshot.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/graph_query_engine.dart';

Memory _memory({
  required String id,
  required String content,
  List<String> entities = const [],
  DateTime? createdAt,
}) {
  return Memory(
    id: id,
    content: content,
    summary: content,
    entities: entities,
    createdAt: createdAt ?? DateTime(2025, 6, 10),
    type: 'voice',
    category: 'Social',
    subCategory: '일상',
  );
}

void main() {
  test('graph DB answers top place with person filter without AI', () {
    final memories = [
      _memory(id: 'a', content: '어머니와 광안리 산책', entities: ['어머니', '광안리']),
      _memory(id: 'b', content: '어머니 광안리 저녁', entities: ['어머니', '광안리']),
      _memory(id: 'c', content: '어머니 집 식사', entities: ['어머니']),
    ];
    final fragments = <String, GraphMemoryFragment>{
      'a': const GraphMemoryFragment(
        meaningTitle: '광안리 산책',
        satellites: [GraphAiSatellite(kind: 'person', label: '어머니'), GraphAiSatellite(kind: 'place', label: '광안리')],
      ),
      'b': const GraphMemoryFragment(
        meaningTitle: '광안리 저녁',
        satellites: [GraphAiSatellite(kind: 'person', label: '어머니'), GraphAiSatellite(kind: 'place', label: '광안리')],
      ),
    };

    final answer = tryAnswerFromGraphDb(
      query: '작년에 어머니와 가장 많이 만난 장소는?',
      memories: memories,
      fragments: fragments,
      localeCode: 'ko',
    );

    expect(answer, isNotNull);
    expect(answer!.text, contains('광안리'));
    expect(answer.skipAiSummary, isTrue);
    expect(answer.relatedMemories, isNotEmpty);
  });

  test('compact search context uses graph fragments not full content', () {
    final memories = [
      _memory(id: 'x', content: '아주 긴 본문 ' * 40, entities: ['Flutter']),
    ];
    final fragments = {
      'x': const GraphMemoryFragment(meaningTitle: 'Flutter 공부', satellites: []),
    };

    final compact = buildCompactSearchContext(memories, fragments);
    expect(compact, contains('Flutter 공부'));
    expect(compact.length, lessThan(300));
    expect(compact.contains('아주 긴 본문'), isFalse);
  });
}
