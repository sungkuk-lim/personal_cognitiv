import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_content_edit.dart';

final _at = DateTime(2026, 1, 1);

void main() {
  test('applyMemoryContentEdit syncs overlapping summary', () {
    final memory = Memory(
      id: 'm1',
      content: '',
      summary: '옛 제목',
      entities: const [],
      createdAt: _at,
    );
    final patched = applyMemoryContentEdit(
      memory: memory,
      newMainText: '새 본문 내용',
      previousBodyText: '옛 제목',
      graphMarkerLabel: '관계망 메모',
    );
    expect(patched.content, '새 본문 내용');
    expect(patched.summary, '새 본문 내용');
  });

  test('applyMemoryContentEdit preserves graph appendix', () {
    final memory = Memory(
      id: 'm1',
      content: '본문\n— 관계망 메모',
      summary: '본문',
      entities: const [],
      createdAt: _at,
    );
    final patched = applyMemoryContentEdit(
      memory: memory,
      newMainText: '수정 본문',
      previousBodyText: '본문',
      graphMarkerLabel: '관계망 메모',
    );
    expect(patched.content, '수정 본문\n— 관계망 메모');
    expect(patched.summary, '수정 본문');
  });

  test('applyMemoryContentEdit syncs summary even when old summary differed', () {
    final memory = Memory(
      id: 'm1',
      content: '원문',
      summary: '별도 요약',
      entities: const [],
      createdAt: _at,
    );
    final patched = applyMemoryContentEdit(
      memory: memory,
      newMainText: '편집된 본문',
      previousBodyText: '원문',
      graphMarkerLabel: '관계망 메모',
    );
    expect(patched.summary, '편집된 본문');
  });

  test('graphMemoryLayoutSignature changes when content changes', () {
    final a = Memory(id: 'a', content: 'one', summary: 's', entities: const [], createdAt: _at);
    final b = a.copyWith(content: 'two');
    expect(graphMemoryLayoutSignature([a]), isNot(graphMemoryLayoutSignature([b])));
  });
}
