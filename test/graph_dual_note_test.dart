import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/voice_memory_format.dart';

const _hospitalDinner = '''
6월 21일 저녁 7시에 병원직원들과 회식을 하게 되었어
참석자로는 배춘남 간호과장, 이미경 간호팀장, 간호사로는 황상기, 김경아, 김경희, 배재석, 임예림, 이재근이 참석하였고 보호사로는 이동명, 서충원, 나, 권용선, 조익태 이렇게 모두 13명이 옥동 중화요리집에서 탕수육, 자장면 등 술과 여러가지 음식을 시켜놓고 이런 저런 얘기를 하면 회식을 했어
''';

GraphNodeData _personNode(String name) => GraphNodeData(
      id: 'person_$name',
      title: name,
      subtitle: '사람',
      color: Colors.pink,
      kind: GraphNodeKind.person,
      size: const Size(112, 48),
      layoutClusterId: 'c1',
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('people list includes 김경아 and 이미경 within satellite cap', () {
    final people = extractPeopleFromMemoryText(_hospitalDinner);
    expect(people, contains('김경아'));
    expect(people, contains('이미경'));
    expect(people.indexOf('김경아'), lessThan(kGraphMaxPeopleSatellites));
    expect(people.indexOf('이미경'), lessThan(kGraphMaxPeopleSatellites));
  });

  test('two graph notes attach to 김경아 and 이미경 separately', () {
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

    final noteKim = buildEntityAnchorGraphNote(
      node: _personNode('김경아'),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );
    final noteLee = buildEntityAnchorGraphNote(
      node: _personNode('이미경'),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    final layout = buildMemoryGraphLayout(
      [dinner, noteKim, noteLee],
      localeCode: 'ko',
      collapseSatellitesByDefault: true,
      satelliteExpansions: const {},
    );

    final kimNoteNode = layout.nodes.where((n) => n.id == 'entity_note_${noteKim.id}').toList();
    final leeNoteNode = layout.nodes.where((n) => n.id == 'entity_note_${noteLee.id}').toList();
    expect(kimNoteNode, isEmpty);
    expect(leeNoteNode, isEmpty);
    expect(layout.nodes.any((n) => n.id == 'person_김경아'), isTrue);
    expect(layout.nodes.any((n) => n.id == 'person_이미경'), isTrue);
  });

  test('focus hub anchor canonicalizes to person node', () {
    final dinner = Memory(
      id: 'dinner',
      content: '6월 21일 병원직원 회식. 이미경 참석',
      summary: '병원 직원 회식',
      entities: const ['이미경'],
      createdAt: DateTime(2026, 6, 21, 19),
    );

    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'focus_hub_이미경',
        title: '이미경',
        subtitle: '사람',
        color: Colors.pink,
        kind: GraphNodeKind.person,
        size: const Size(148, 72),
        layoutClusterId: 'c1',
      ),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    expect(note.userMemo, contains('graph_anchor:person_이미경'));

    final layout = buildMemoryGraphLayout(
      [dinner, note],
      localeCode: 'ko',
      collapseSatellitesByDefault: true,
    );
    expect(layout.nodes.any((n) => n.id == 'person_이미경'), isTrue);
    expect(layout.nodes.any((n) => n.id.startsWith('entity_note_')), isFalse);
  });
}
