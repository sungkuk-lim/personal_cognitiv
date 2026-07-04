import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_layout.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  test('mergeDefaultSatelliteExpansions auto-expands when few memories', () {
    final memories = [
      Memory(
        id: 'a',
        content: '어머니와 저녁을 먹었다',
        summary: '어머니와 저녁',
        entities: const ['어머니'],
        createdAt: DateTime(2026, 7, 1),
        type: 'voice',
        isLocalOnly: true,
      ),
    ];

    final merged = mergeDefaultSatelliteExpansions(
      memories: memories,
      userExpansions: const {},
      graphFragments: const {},
      localeCode: 'ko',
    );

    expect(merged['a'], GraphSatelliteExpandMode.all);
  });

  test('mergeDefaultSatelliteExpansions respects user collapse', () {
    final memories = [
      Memory(
        id: 'a',
        content: '민수와 카페',
        summary: '카페',
        entities: const ['민수'],
        createdAt: DateTime(2026, 7, 2),
        type: 'voice',
        isLocalOnly: true,
      ),
    ];

    final merged = mergeDefaultSatelliteExpansions(
      memories: memories,
      userExpansions: const {},
      graphFragments: const {},
      localeCode: 'ko',
      collapsedMemoryIds: {'a'},
    );

    expect(merged.containsKey('a'), isFalse);
  });
}
