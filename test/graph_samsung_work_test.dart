import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_satellites.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

Memory _mem(String content) {
  return Memory(
    id: 'samsung_work',
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: DateTime(2026, 7, 5),
    isLocalOnly: true,
  );
}

void main() {
  const text = '민수와 지영은 삼성전자에서 함께 일한다';

  test('extracts both people and samsung org', () {
    expect(extractPeopleFromMemoryText(text), containsAll(['민수', '지영']));
    final bundle = extractMemoryEntities(_mem(text), localeCode: 'ko');
    expect(bundle.people, containsAll(['민수', '지영']));
    expect(bundle.organizations, contains('삼성전자'));
    expect(bundle.eventTitle, '삼성전자 근무');
  });

  test('graph shows two person nodes', () {
    final memory = _mem(text);
    final visible = visibleGraphSatellitesForMemory(memory, localeCode: 'ko');
    expect(visible.people, containsAll(['민수', '지영']));

    final layout = buildMemoryGraphLayout(
      [memory],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );

    expect(
      layout.nodes.where((n) => n.kind == GraphNodeKind.person && n.title == '민수'),
      hasLength(1),
    );
    expect(
      layout.nodes.where((n) => n.kind == GraphNodeKind.person && n.title == '지영'),
      hasLength(1),
    );
    expect(
      layout.nodes.where((n) => n.kind == GraphNodeKind.organization && n.title == '삼성전자'),
      isEmpty,
    );
  });
}
