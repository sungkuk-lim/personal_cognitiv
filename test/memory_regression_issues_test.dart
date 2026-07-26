import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_meaning.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_content_edit.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

void main() {
  const watermelon =
      '오늘 근무시간 중 짬나는 시간에 이미경팀장, 김경희, 서충원, 권용선, 나 이렇게 다섯명이서 수박 먹었다';
  const watermelonShort =
      '오늘 근무시간에 이미경, 김경희, 서충원, 권용선, 나 이렇게 다섯명이서 수박 먹었다';

  test('comma list with attached title extracts all people', () {
    final people = extractPeopleFromMemoryText(watermelon);
    expect(people, containsAll(['이미경', '김경희', '서충원', '권용선', '나']));
  });

  test('watermelon memory shows person satellites in graph layout', () {
    final memory = Memory(
      id: 'watermelon',
      content: watermelonShort,
      summary: '',
      entities: const [],
      createdAt: DateTime(2025, 7, 7),
    );
    final bundle = extractMemoryEntities(memory, localeCode: 'ko');
    expect(bundle.people, containsAll(['이미경', '김경희', '서충원', '권용선']));

    final visible = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(
      visible.people,
      containsAll(['이미경', '김경희', '서충원', '권용선']),
      reason: 'hub=${bundle.eventTitle}',
    );

    final layout = buildMemoryFocusGraphLayout(memory, localeCode: 'ko');
    final personNodes = layout.layout.nodes.where((n) => n.kind == GraphNodeKind.person).toList();
    expect(personNodes.length, greaterThanOrEqualTo(4), reason: personNodes.map((n) => n.title).join(', '));
  });

  test('content edit preserves body and refreshes summary', () {
    const original = '나는 아버지에게 낚시를 배웠다';
    final memory = Memory(
      id: 'm1',
      content: original,
      summary: '소중한 시간과 유대는 삶에 깊은 감동을 주었다.',
      entities: const [],
      createdAt: DateTime(2025, 6, 1),
      category: 'Social',
    );
    final edited = applyMemoryContentEdit(
      memory: memory,
      newMainText: '나는 아버지에게 낚시와 캠핑을 배웠다',
      previousBodyText: original,
      graphMarkerLabel: '관계망 대화',
    );
    expect(edited.content, contains('낚시'));
    expect(edited.content, isNotEmpty);
    expect(edited.summary, isNotEmpty);
  });

  test('graph meaning prefers sentence over chip hub for walk and book memory', () {
    final memory = Memory(
      id: 'm2',
      content: '오늘 저녁에 산책하고 집에서 책을 읽었다. 소중한 시간과 유대는 삶에 깊은 감동을 주었다.',
      summary: '기억 이어가기',
      entities: const [],
      createdAt: DateTime(2025, 6, 2),
      category: 'Social',
    );
    final meaning = graphMeaningSentence(memory, localeCode: 'ko');
    expect(meaning, isNot(contains('산책·책')));
    expect(meaning.length, greaterThan(8));
  });
}
