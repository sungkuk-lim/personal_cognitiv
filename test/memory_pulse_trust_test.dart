import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/graph/graph_chat_save.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/memory_pulse_service.dart';
import 'package:personal_cognitive/utils/trust_source.dart';

void main() {
  test('buildDailyMemoryPulse picks on-this-day memory', () {
    final today = DateTime(2026, 6, 22);
    final memory = Memory(
      id: 'old',
      content: '집사람과 길안천',
      summary: '길안천 나들이',
      entities: const ['집사람'],
      createdAt: DateTime(2024, 6, 22),
    );
    final offer = buildDailyMemoryPulse([memory], now: today, localeCode: 'ko');
    expect(offer, isNotNull);
    expect(offer!.kind, MemoryPulseKind.onThisDay);
    expect(offer.yearsAgo, 2);
  });

  test('trust source classifies graph note as AI assist', () {
    final note = Memory(
      id: 'n1',
      content: 'fact',
      summary: 'fact',
      entities: const [],
      createdAt: DateTime.now(),
      type: 'graph_note',
    );
    expect(isAiAssistedMemory(note), isTrue);
    final voice = Memory(
      id: 'v1',
      content: '오늘 저녁',
      summary: '저녁',
      entities: const [],
      createdAt: DateTime.now(),
      type: 'voice',
    );
    expect(trustSourceForMemory(voice), MemoryTrustSource.userRecord);
  });
}
