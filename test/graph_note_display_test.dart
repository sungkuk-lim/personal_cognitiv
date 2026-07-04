import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_image_memos.dart';

void main() {
  test('graph note userMemo is hidden from timeline display', () {
    final note = Memory(
      id: 'note1',
      content: '배춘남 — 못씀\n\n— 관계망 대화 (2026-06-22 10:00) —',
      summary: '배춘남 · 못씀',
      entities: const ['배춘남'],
      createdAt: DateTime(2026, 6, 21, 19),
      type: kGraphNoteMemoryType,
      userMemo: 'graph_related:ae46b771-60f6-4fae-8aa4-3374039e0c7e|graph_anchor:person_배춘남',
    );

    expect(isInternalGraphNoteUserMemo(note.userMemo), isTrue);
    expect(displayUserMemoForMemory(note), isEmpty);
    expect(displayMemoForMemory(note, const {}), isEmpty);
  });
}
