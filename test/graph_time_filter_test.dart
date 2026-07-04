import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_time_filter.dart';

void main() {
  test('filterMemoriesForGraphRange keeps recent memories only', () {
    final now = DateTime.now();
    final memories = [
      Memory(
        id: 'old',
        content: 'old',
        summary: '',
        entities: const [],
        createdAt: now.subtract(const Duration(days: 40)),
      ),
      Memory(
        id: 'new',
        content: 'new',
        summary: '',
        entities: const [],
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];

    final week = filterMemoriesForGraphRange(memories, GraphTimeRange.days7);
    expect(week.map((m) => m.id), ['new']);

    final all = filterMemoriesForGraphRange(memories, GraphTimeRange.all);
    expect(all.length, 2);
  });
}
