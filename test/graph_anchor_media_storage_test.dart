import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_grouping.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  test('media-only graph note is hidden from timeline', () {
    final note = buildMediaOnlyGraphNote(
      anchorNodeId: 'person_집사람',
      anchorLabel: '집사람',
      localeCode: 'ko',
      relatedMemoryId: 'gilancheon',
    );
    expect(isGraphAnchorMediaStorage(note), isTrue);
    expect(isUserFacingMemory(note), isFalse);

    final dinner = Memory(
      id: 'gilancheon',
      content: '길안천 나들이',
      summary: '길안천 나들이',
      entities: const ['집사람'],
      createdAt: DateTime(2026, 6, 22, 14),
      lat: 36.5,
      lng: 128.7,
    );

    final groups = groupMemoriesForTimeline([dinner, note]);
    expect(groups.length, 1);
    expect(groups.first.memories.every((m) => m.id == 'gilancheon'), isTrue);
  });

  test('AI conversation graph note stays on timeline', () {
    final dinner = Memory(
      id: 'dinner',
      content: '6월 21일 병원직원 회식. 김경아 참석',
      summary: '병원 직원 회식',
      entities: const ['김경아'],
      createdAt: DateTime(2026, 6, 21, 19),
      lat: 35.9,
      lng: 128.6,
    );
    final note = buildEntityAnchorGraphNote(
      node: GraphNodeData(
        id: 'person_김경아',
        title: '김경아',
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

    expect(isGraphAnchorMediaStorage(note), isFalse);
    expect(isUserFacingMemory(note), isTrue);

    final groups = groupMemoriesForTimeline([dinner, note]);
    expect(groups.first.memories.length, 2);
  });

  test('normalizeGraphNoteMemory repairs media anchor type', () {
    final note = buildMediaOnlyGraphNote(
      anchorNodeId: 'person_집사람',
      anchorLabel: '집사람',
      localeCode: 'ko',
    ).copyWith(type: 'image');

    final fixed = normalizeGraphNoteMemory(note);
    expect(fixed.type, kGraphNoteMemoryType);
  });
}
