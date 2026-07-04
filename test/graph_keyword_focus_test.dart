import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_keyword_ui.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('memoryMatchesKeyword finds entity and content', () {
    final memory = Memory(
      id: '1',
      content: '어머니와 저녁 식사',
      summary: '가족 식사',
      entities: const ['어머니'],
      createdAt: DateTime(2025, 6, 1),
    );
    expect(memoryMatchesKeyword(memory, '어머니'), isTrue);
    expect(memoryMatchesKeyword(memory, '아버지'), isFalse);
  });

  test('buildKeywordFocusGraphLayout hub and memories only', () {
    final memories = [
      Memory(
        id: 'a',
        content: '어머니와 식사',
        summary: '식사',
        entities: const ['어머니'],
        createdAt: DateTime(2025, 6, 1),
      ),
      Memory(
        id: 'b',
        content: '친구와 영화',
        summary: '영화',
        entities: const ['민수'],
        createdAt: DateTime(2025, 6, 2),
      ),
    ];

    final result = buildKeywordFocusGraphLayout('어머니', memories, localeCode: 'ko');
    expect(result.totalCount, 1);
    expect(result.shownCount, 1);
    expect(result.layout.nodes.any((n) => n.id.startsWith('focus_hub_')), isTrue);
    expect(result.layout.nodes.where((n) => n.kind == GraphNodeKind.memory), hasLength(1));
    expect(result.layout.edges, hasLength(1));
    expect(result.layout.nodes.where((n) => n.kind == GraphNodeKind.person), hasLength(1));
    expect(result.layout.nodes.any((n) => n.id.startsWith('focus_hub_')), isTrue);
  });

  test('classifyKeyword treats beach names as place not organization', () {
    final memory = Memory(
      id: 'gwangalli',
      content: '광안리 해수욕장에서 즐거웠다',
      summary: '광안리',
      entities: const ['광안리 해수욕장'],
      createdAt: DateTime(2025, 6, 17),
    );
    expect(classifyKeyword('광안리 해수욕장', memory), MemoryKeywordKind.place);

    final result = buildKeywordFocusGraphLayout('광안리 해수욕장', [memory], localeCode: 'ko');
    final hub = result.layout.nodes.firstWhere((n) => n.id.startsWith('focus_hub_'));
    expect(hub.kind, GraphNodeKind.place);
    expect(hub.subtitle, isEmpty);
  });

  test('집사람 키워드 포커스 — 집사람 관련 위성만, 태민 위성 없음', () {
    final gilancheon = Memory(
      id: 'gilancheon',
      content: '아버지, 어머니, 나, 집사람, 예린이, 태민이 길안천 나들이',
      summary: '길안천 나들이',
      entities: const ['집사람', '태민', '길안천'],
      createdAt: DateTime(2026, 6, 22),
    );
    final unrelated = Memory(
      id: 'work',
      content: '회사에서 프로젝트 회의',
      summary: '회의',
      entities: const ['민수'],
      createdAt: DateTime(2026, 6, 1),
    );

    expect(memoryMatchesKeyword(gilancheon, '집사람'), isTrue);
    expect(memoryMatchesKeyword(unrelated, '집사람'), isFalse);

    final result = buildKeywordFocusGraphLayout('집사람', [gilancheon, unrelated], localeCode: 'ko');
    expect(result.totalCount, 1);
    expect(result.layout.nodes.where((n) => n.title == '집사람'), isNotEmpty);
    expect(result.layout.nodes.where((n) => n.id.startsWith('memory_')), hasLength(1));
    expect(result.layout.nodes.where((n) => n.kind == GraphNodeKind.person).map((n) => n.title), contains('집사람'));
  });
}
