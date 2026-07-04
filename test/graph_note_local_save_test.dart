import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  test('entity anchor graph notes are always local-only fragments', () {
    final dinner = Memory(
      id: 'dinner',
      content: '6월 21일 병원직원 회식. 배춘남 참석',
      summary: '병원 직원 회식',
      entities: const ['배춘남'],
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );

    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'person_배춘남',
        title: '배춘남',
        subtitle: '사람',
        color: const Color(0xFFEC407A),
        kind: GraphNodeKind.person,
        size: const Size(112, 48),
        layoutClusterId: 'c1',
      ),
      userLines: const ['못씀'],
      contextMemories: [dinner],
      localeCode: 'ko',
      markerLabel: '관계망 대화',
    );

    expect(isGraphNoteMemory(note), isTrue);
    expect(note.isLocalOnly, isTrue);
    expect(note.type, kGraphNoteMemoryType);
    expect(note.userMemo, contains('graph_related:dinner'));
    expect(note.userMemo, contains('graph_anchor:person_배춘남'));
  });
}
