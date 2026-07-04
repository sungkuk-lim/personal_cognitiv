import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/local_memory_thread_service.dart';

void main() {
  final motherDinner = Memory(
    id: '1',
    content: '어머니와 함께 저녁을 먹었다',
    summary: '어머니와 저녁',
    entities: const ['어머니'],
    createdAt: DateTime(2026, 7, 4, 18),
    type: 'voice',
    isLocalOnly: true,
  );

  final motherCafe = Memory(
    id: '2',
    content: '어머니랑 카페에서 수다',
    summary: '어머니와 카페',
    entities: const ['어머니', '카페'],
    createdAt: DateTime(2026, 6, 10),
    type: 'voice',
    isLocalOnly: true,
  );

  final unrelated = Memory(
    id: '3',
    content: '회사 회의',
    summary: '회의',
    entities: const [],
    createdAt: DateTime(2026, 5, 1),
    type: 'voice',
    isLocalOnly: true,
  );

  test('findRelated links memories by shared person', () {
    final related = LocalMemoryThreadService.findRelated(
      saved: motherDinner,
      allMemories: [motherDinner, motherCafe, unrelated],
      excludeId: motherDinner.id,
      localeCode: 'ko',
    );
    expect(related.length, 1);
    expect(related.first.id, '2');
  });

  test('findRelated links same-day memories', () {
    final sameDay = Memory(
      id: '4',
      content: '저녁 후 산책',
      summary: '산책',
      entities: const [],
      createdAt: DateTime(2026, 7, 4, 20),
      type: 'voice',
      isLocalOnly: true,
    );
    final related = LocalMemoryThreadService.findRelated(
      saved: motherDinner,
      allMemories: [motherDinner, sameDay, unrelated],
      excludeId: motherDinner.id,
      localeCode: 'ko',
    );
    expect(related.any((m) => m.id == '4'), isTrue);
  });
}
