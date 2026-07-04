import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/features/graph/graph_node_context.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_grouping.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _hospitalDinner = '''
6월 21일 저녁 7시에 병원직원들과 회식을 하게 되었어
참석자로는 배춘남 간호과장, 이미경 간호팀장, 간호사로는 황상기, 김경아, 김경희, 배재석, 임예림, 이재근이 참석하였고 보호사로는 이동명, 서충원, 나, 권용선, 조익태 이렇게 모두 13명이 옥동 중화요리집에서 탕수육, 자장면 등 술과 여러가지 음식을 시켜놓고 이런 저런 얘기를 하면 회식을 했어
''';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  late Memory dinner;
  late GraphLayout expandedLayout;

  setUp(() {
    final people = extractPeopleFromMemoryText(_hospitalDinner);
    dinner = Memory(
      id: 'hospital_dinner',
      content: _hospitalDinner,
      summary: '병원 직원 회식',
      entities: buildVoiceGraphEntities(speechPlace: '옥동 중화요리집', peopleNames: people),
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );
    expandedLayout = buildMemoryGraphLayout(
      [dinner],
      localeCode: 'ko',
      collapseSatellitesByDefault: false,
    );
  });

  test('배춘남 person node reaches dinner memory through edges', () {
    final baeNode = expandedLayout.nodes.firstWhere((n) => n.id == 'person_배춘남');
    final linked = connectedMemoriesForNode(
      node: baeNode,
      allMemories: [dinner],
      edges: expandedLayout.edges,
    );
    expect(linked.map((m) => m.id), contains('hospital_dinner'));
  });

  test('김경아 person node reaches dinner memory through edges', () {
    final kimNode = expandedLayout.nodes.firstWhere((n) => n.id == 'person_김경아');
    final linked = connectedMemoriesForNode(
      node: kimNode,
      allMemories: [dinner],
      edges: expandedLayout.edges,
    );
    expect(linked.map((m) => m.id), contains('hospital_dinner'));
  });

  test('graph note without related memo still attaches to 배춘남 in dinner cluster', () {
    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'person_배춘남',
        title: '배춘남',
        subtitle: '사람',
        color: Colors.pink,
        kind: GraphNodeKind.person,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      ),
      userLines: const ['못씀'],
      contextMemories: const [],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );
    expect(note.userMemo, contains('graph_anchor:person_배춘남'));
    expect(note.userMemo, isNot(contains('graph_related:')));

    final layout = buildMemoryGraphLayout(
      [dinner, note],
      localeCode: 'ko',
      collapseSatellitesByDefault: true,
    );

    final noteNode = layout.nodes.where((n) => n.id == 'entity_note_${note.id}').toList();
    expect(noteNode, isEmpty);
    expect(layout.nodes.any((n) => n.id == 'person_배춘남'), isTrue);
  });

  test('resolveGraphChatContextMemories infers dinner when edges are empty', () {
    final baeNode = GraphNodeData(
      id: 'person_배춘남',
      title: '배춘남',
      subtitle: '사람',
      color: Colors.pink,
      kind: GraphNodeKind.person,
      size: const Size(112, 48),
      layoutClusterId: 'c1',
    );
    final linked = resolveGraphChatContextMemories(
      node: baeNode,
      allMemories: [dinner],
      edges: const [],
    );
    expect(linked.map((m) => m.id), contains('hospital_dinner'));
  });

  test('dinner plus graph notes shows day hub with memory as satellite anchor', () {
    final people = extractPeopleFromMemoryText(_hospitalDinner);
    final dinner = Memory(
      id: 'hospital_dinner',
      content: _hospitalDinner,
      summary: '병원 직원 회식',
      entities: buildVoiceGraphEntities(speechPlace: '옥동 중화요리집', peopleNames: people),
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );
    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'person_김경아',
        title: '김경아',
        subtitle: '사람',
        color: Colors.pink,
        kind: GraphNodeKind.person,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      ),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    final layout = buildMemoryGraphLayout(
      [dinner, note],
      localeCode: 'ko',
      collapseSatellitesByDefault: true,
    );

    expect(layout.nodes.any((n) => n.id.startsWith('group_')), isFalse);
    expect(layout.nodes.any((n) => n.id.startsWith('event_hub_')), isFalse);
    expect(layout.nodes.any((n) => n.id == 'memory_hospital_dinner'), isTrue);
    expect(layout.nodes.any((n) => n.id == 'person_김경아'), isTrue);
    expect(
      layout.edges.any(
        (e) =>
            (e.fromId == 'memory_hospital_dinner' && e.toId == 'person_김경아') ||
            (e.fromId == 'person_김경아' && e.toId == 'memory_hospital_dinner'),
      ),
      isTrue,
    );

    final defaults = initialGraphPositions(layout.nodes, layout.edges, const Size(1200, 900));
    final memoryPos = defaults['memory_hospital_dinner'];
    expect(memoryPos, isNotNull);
  });
}
