import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_context_lens.dart';

void main() {
  Memory mem({String sub = '', String category = 'Social'}) {
    return Memory(
      id: 'm1',
      summary: 'test',
      content: 'content',
      category: category,
      subCategory: sub,
      entities: const [],
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('all lens includes every memory', () {
    final list = [mem(sub: '가족'), mem(sub: '')];
    expect(filterMemoriesForGraphLens(list, GraphContextLens.all, 'ko').length, 2);
  });

  test('pet lens matches 반려견/반려묘 subCategory', () {
    final pet = mem(sub: '반려견/반려묘');
    final family = mem(sub: '가족');
    final filtered = filterMemoriesForGraphLens(
      [pet, family],
      GraphContextLens.pet,
      'ko',
    );
    expect(filtered, [pet]);
  });

  test('general lens matches memories without input context', () {
    final general = mem(sub: '');
    final family = mem(sub: '가족');
    final filtered = filterMemoriesForGraphLens(
      [general, family],
      GraphContextLens.general,
      'ko',
    );
    expect(filtered, [general]);
  });
}
