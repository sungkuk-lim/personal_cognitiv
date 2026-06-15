import 'package:flutter_test/flutter_test.dart';

import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/ocr_utils.dart';

void main() {
  test('Memory copyWith preserves isLocalOnly', () {
    final m = Memory(
      id: 'a',
      content: 'c',
      summary: 's',
      entities: const [],
      createdAt: DateTime.now(),
    );
    final local = m.copyWith(isLocalOnly: true);
    expect(local.isLocalOnly, isTrue);
    expect(local.id, 'a');
  });

  test('graphTitleForMemory prefers summary', () {
    final m = Memory(
      id: '1',
      content: 'long content here',
      summary: '강남 카페',
      entities: const [],
      createdAt: DateTime.now(),
    );
    expect(graphTitleForMemory(m), '강남 카페');
  });

  test('graphKeywordsForMemory uses entities', () {
    final m = Memory(
      id: '1',
      content: 'x',
      summary: 'y',
      entities: const ['민수', '카페'],
      createdAt: DateTime.now(),
    );
    expect(graphKeywordsForMemory(m), ['민수', '카페']);
  });
}
