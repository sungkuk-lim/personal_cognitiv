import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_list_view.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';

void main() {
  test('graph list entries omit status noise and keep people', () {
    const text =
        '오늘 대성그린병원 외진현황으로는 성소병원에 이정숙 정형외과, 김명희 안과, '
        '기우대 안동병원에 소화기내과 총7명이 외진나왔어';
    var memory = Memory(
      id: 'list_verify',
      content: text,
      summary: text,
      entities: const [],
      createdAt: DateTime(2026, 7, 12),
    );
    memory = enrichMemoryGraphSemantics(memory);

    final entries = buildGraphListEntries([memory]);
    expect(entries.people.map((e) => e.label), isNot(contains('현황')));
    expect(entries.people.map((e) => e.label), contains('이정숙'));
    expect(entries.memoryItems, isNotEmpty);
  });
}
