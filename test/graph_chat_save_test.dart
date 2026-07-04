import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_place_cache.dart';

GraphNodeData _personNode(String name) => GraphNodeData(
      id: 'person_$name',
      title: name,
      subtitle: '사람',
      color: Colors.pink,
      kind: GraphNodeKind.person,
      size: const Size(112, 48),
      layoutClusterId: 'c1',
    );

GraphNodeData _eventHubNode(Memory memory) => GraphNodeData(
      id: 'event_hub_${memory.id}',
      title: '병원 직원 회식',
      subtitle: '이벤트',
      color: Colors.purple,
      kind: GraphNodeKind.activity,
      size: const Size(168, 64),
      layoutClusterId: 'c1',
    );

void main() {
  final dinner = Memory(
    id: 'dinner',
    content: '6월 21일 병원직원 회식',
    summary: '병원 직원 회식',
    entities: const ['배춘남', '김경아'],
    createdAt: DateTime(2026, 6, 21, 19),
  );

  test('person node creates graph_note memory anchored on person', () {
    final result = planGraphChatSave(
      node: _personNode('김경아'),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      allMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    expect(result, isNotNull);
    expect(result!.kind, GraphChatSaveKind.entityAnchor);
    expect(result.isNewMemory, isTrue);
    expect(result.memory.type, kGraphNoteMemoryType);
    expect(result.memory.entities.first, '김경아');
    expect(result.memory.content, contains('김경아 — 못씀'));
    expect(result.memory.content, isNot(contains('관련 기억')));
    expect(result.memory.userMemo, 'graph_related:dinner|graph_anchor:person_김경아');
    expect(result.memory.summary, '김경아 · 못씀');
  });

  test('event hub node appends to existing memory body', () {
    final result = planGraphChatSave(
      node: _eventHubNode(dinner),
      userLines: const ['그날 분위기 좋았다'],
      contextMemories: [dinner],
      allMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    expect(result, isNotNull);
    expect(result!.kind, GraphChatSaveKind.eventAppend);
    expect(result.isNewMemory, isFalse);
    expect(result.memory.id, dinner.id);
    expect(result.memory.content, contains('— 관계망 대화'));
    expect(result.memory.content, contains('그날 분위기 좋았다'));
  });

  test('splitMemoryBodyForDisplay separates event appendix', () {
    final memory = dinner.copyWith(
      content: '${dinner.content}\n\n— 관계망 대화 (2026-06-22 10:00) —\n못씀',
    );
    final parts = splitMemoryBodyForDisplay(memory, graphMarkerLabel: '관계망 대화');
    expect(parts.isEntityNote, isFalse);
    expect(parts.mainText, dinner.content);
    expect(parts.appendixText, contains('못씀'));
  });

  test('entity anchor appends to existing graph note', () {
    final existing = buildEntityAnchorGraphNote(
      node: _personNode('김경아'),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );
    final result = planGraphChatSave(
      node: _personNode('김경아'),
      userLines: const ['다시 만남'],
      contextMemories: [dinner],
      allMemories: [dinner, existing],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );
    expect(result, isNotNull);
    expect(result!.isNewMemory, isFalse);
    expect(result.memory.id, existing.id);
    expect(result.memory.content, contains('다시 만남'));
  });

  test('graphNoteFactTitle omits anchor-only media note', () {
    final note = Memory(
      id: 'n1',
      content: '예린엄마',
      summary: '예린엄마 ·',
      entities: const ['예린엄마'],
      createdAt: DateTime(2026, 6, 21),
      type: kGraphNoteMemoryType,
      userMemo: 'graph_anchor:person_예린엄마',
    );
    expect(graphNoteFactTitle(note), '');
    expect(graphNoteCardBody(note), '');
    expect(graphNoteDetailBody(note), '');
  });

  test('graphNoteFactTitle keeps user text after anchor', () {
    final note = buildEntityAnchorGraphNote(
      node: _personNode('김경아'),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );
    expect(graphNoteFactTitle(note), '못씀');
    expect(graphNoteCardBody(note), '못씀');
  });

  test('displayPlaceAddress prefers full address cache for graph note', () {
    final dinnerAtPlace = dinner.copyWith(lat: 37.5, lng: 127.0);
    final note = buildEntityAnchorGraphNote(
      node: _personNode('김경아'),
      userLines: const ['못씀'],
      contextMemories: [dinnerAtPlace],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );
    final shortCache = {'37.5000,127.0000': '강남역'};
    final fullCache = {'37.5000,127.0000': '서울특별시 강남구 강남대로 지하 396'};
    expect(
      displayPlaceAddress(note, shortCache, fullCache, localeCode: 'ko', allMemories: [dinnerAtPlace, note]),
      '서울특별시 강남구 강남대로 지하 396',
    );
  });
}
