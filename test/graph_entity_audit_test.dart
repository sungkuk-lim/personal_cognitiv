import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_event_layout.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/graph_insights_service.dart';
import 'package:personal_cognitive/utils/graph_keyword_focus.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';
import 'package:personal_cognitive/utils/memory_theme_tags.dart';
import 'package:personal_cognitive/utils/recall_anchor.dart';

Memory _mem({
  required String id,
  required String content,
  List<String> entities = const [],
  DateTime? createdAt,
}) {
  return Memory(
    id: id,
    userId: 'u',
    content: content,
    summary: content,
    entities: entities,
    createdAt: createdAt ?? DateTime(2026, 6, 10),
    isLocalOnly: true,
  );
}

void main() {
  const pollutedEntities = [
    '철수',
    '카페',
    'rel:방문:카페',
    'rel:동행:철수',
    'event:slug:철수와-카페',
    '철수와 카페',
    'tag:emotion:행복',
  ];

  test('userVisibleEntityLabels strips internal and composite labels', () {
    final memory = _mem(id: '1', content: '철수와 카페에서 이야기', entities: pollutedEntities);
    final visible = userVisibleEntityLabels(memory);
    expect(visible, contains('철수'));
    expect(visible, contains('카페'));
    expect(visible, everyElement(isNot(startsWith('rel:'))));
    expect(visible, everyElement(isNot(startsWith('event:'))));
    expect(visible, everyElement(isNot(startsWith('tag:'))));
    expect(visible, isNot(contains('철수와 카페')));
  });

  test('displayEntitiesForMemory matches userVisibleEntityLabels', () {
    final memory = _mem(id: '1', content: '철수와 카페', entities: pollutedEntities);
    expect(displayEntitiesForMemory(memory), userVisibleEntityLabels(memory));
  });

  test('primaryKeywordForMemories never picks internal rel tag', () {
    final memory = enrichMemoryGraphSemantics(
      _mem(id: '1', content: '철수와 카페에서 3시간 이야기.'),
    );
    final keyword = primaryKeywordForMemories([memory], '');
    expect(keyword, isNot(startsWith('rel:')));
    expect(keyword, isNot(contains('철수와 카페')));
  });

  test('estimateGraphNodeCount ignores internal entity tags', () {
    final memory = _mem(id: '1', content: '철수와 카페', entities: pollutedEntities);
    final withInternal = estimateGraphNodeCount([memory], {});
    final withClean = estimateGraphNodeCount(
      [memory.copyWith(entities: userVisibleEntityLabels(memory))],
      {},
    );
    expect(withInternal, lessThanOrEqualTo(withClean + 1));
    expect(withInternal, lessThan(1 + pollutedEntities.length));
  });

  test('primaryStoryPlaceLabel ignores rel:방문 tags', () {
    final memory = _mem(
      id: '1',
      content: '철수와 광안리 해수욕장에서 이야기',
      entities: ['rel:방문:광안리해수욕장', '광안리 해수욕장'],
    );
    final place = primaryStoryPlaceLabel(memory);
    expect(place, isNotNull);
    expect(place, isNot(startsWith('rel:')));
    expect(place, contains('광안리'));
  });

  test('applyGraphChatAppend does not re-copy internal tags', () {
    final memory = _mem(id: '1', content: '철수와 카페', entities: pollutedEntities);
    final updated = applyGraphChatAppend(
      memory: memory,
      userLines: const ['추가 메모'],
      localeCode: 'ko',
      markerLabel: '관계망',
    );
    expect(updated.entities, everyElement(isNot(startsWith('rel:'))));
    expect(updated.entities, everyElement(isNot(startsWith('event:'))));
    expect(updated.entities, isNot(contains('철수와 카페')));
  });

  test('userVisibleEntityLabels drops stale stored name after content edit', () {
    final memory = _mem(
      id: '1',
      content: '민수와 카페에서 이야기',
      entities: ['철수', 'rel:동행:철수', '카페', 'rel:방문:카페'],
    );
    final visible = userVisibleEntityLabels(memory);
    expect(visible, contains('민수'));
    expect(visible, contains('카페'));
    expect(visible, isNot(contains('철수')));
  });

  test('buildEventGraphLayout ignores stale rel tags after rename', () {
    final memory = _mem(
      id: '1',
      content: '민수와 카페에서 이야기',
      entities: ['철수', 'rel:동행:철수', '카페', 'rel:방문:카페'],
    );
    final layout = buildEventGraphLayout([memory], localeCode: 'ko');
    expect(layout.nodes.where((n) => n.title == '철수'), isEmpty);
    final eventHubs = layout.nodes.where((n) => n.kind == GraphNodeKind.eventHub).toList();
    expect(eventHubs, hasLength(1));
    expect(eventHubs.first.title, contains('민수'));
    expect(layout.nodes.where((n) => n.title.startsWith('rel:')), isEmpty);
  });

  test('buildEventGraphLayout merges event hub without duplicate satellites', () {
    final memory = enrichMemoryGraphSemantics(
      _mem(id: 'cafe', content: '철수와 카페에서 3시간 이야기.'),
    );
    final layout = buildEventGraphLayout([memory], localeCode: 'ko');

    final eventHubs = layout.nodes.where((n) => n.kind == GraphNodeKind.eventHub).toList();
    expect(eventHubs, hasLength(1));
    expect(eventHubs.first.title, contains('철수'));
    expect(eventHubs.first.title, contains('카페'));

    expect(layout.nodes.where((n) => n.title.startsWith('rel:')), isEmpty);
    expect(layout.nodes.where((n) => n.title == '철수와 카페'), isEmpty);
    expect(layout.nodes.where((n) => n.kind == GraphNodeKind.person && n.title == '철수'), isEmpty);
    expect(layout.nodes.where((n) => n.kind == GraphNodeKind.place && n.title == '카페'), isEmpty);
  });

  test('buildEventGraphLayout omits redundant memory card when title matches event', () {
    final memory = enrichMemoryGraphSemantics(
      _mem(id: 'solo', content: '철수와 카페에서 3시간 이야기.'),
    );
    final layout = buildEventGraphLayout([memory], localeCode: 'ko');
    expect(layout.nodes.where((n) => n.kind == GraphNodeKind.memory), isEmpty);
    expect(layout.nodes.where((n) => n.kind == GraphNodeKind.eventHub), hasLength(1));
  });
}
