import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/embedding_utils.dart';

void main() {
  test('cosineSimilarity returns 1 for identical vectors', () {
    expect(cosineSimilarity([1, 0, 0], [1, 0, 0]), closeTo(1, 0.001));
  });

  test('cosineSimilarity returns 0 for orthogonal vectors', () {
    expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0, 0.001));
  });

  test('buildMemoryGraphLayout links memories by embedding similarity', () {
    final base = List<double>.generate(8, (i) => (i + 1) * 0.1);
    final similar = base.map((v) => v * 0.98 + 0.001).toList();
    final unrelated = List<double>.generate(base.length, (i) => i.isEven ? 1.0 : -1.0);

    final memories = [
      Memory(
        id: 'a',
        content: 'foo bar baz',
        summary: 'foo',
        entities: const ['x1'],
        createdAt: DateTime(2026, 1, 1, 10),
        lat: 35.1,
        lng: 128.9,
        embedding: base,
      ),
      Memory(
        id: 'b',
        content: 'qux quux corge',
        summary: 'qux',
        entities: const ['x2'],
        createdAt: DateTime(2026, 2, 1, 10),
        lat: 36.2,
        lng: 127.1,
        embedding: similar,
      ),
      Memory(
        id: 'c',
        content: 'zzz unrelated',
        summary: 'zzz',
        entities: const ['x3'],
        createdAt: DateTime(2026, 3, 1, 10),
        lat: 33.0,
        lng: 126.0,
        embedding: unrelated,
      ),
    ];

    final layout = buildMemoryGraphLayout(memories);
    final semantic = layout.edges.where((e) => e.semanticLink).toList();
    expect(semantic, isNotEmpty);
    expect(
      semantic.any((e) => (e.fromId == 'memory_a' && e.toId == 'memory_b') || (e.fromId == 'memory_b' && e.toId == 'memory_a')),
      isTrue,
    );
    expect(
      semantic.any((e) => e.fromId.contains('memory_c') || e.toId.contains('memory_c')),
      isFalse,
    );
  });
}
