import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/features/replay/replay_insight_cards.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';

Memory _mem(String id, String content, {DateTime? createdAt}) {
  return Memory(
    id: id,
    userId: 'u',
    content: content,
    summary: content,
    entities: const [],
    createdAt: createdAt ?? DateTime(2026, 7, 5),
    isLocalOnly: true,
  );
}

void main() {
  test('single memory with multiple entities produces no insight cards', () {
    const text = '아들이 오늘 컴퓨터 활용 능력 1급 시험을 친대 잘 쳤으면 좋겠어';
    final cards = buildReplayInsightCards(
      [_mem('m1', text)],
      localeCode: 'ko',
    );
    expect(cards, isEmpty);
  });

  test('entity with two memories produces one pattern card', () {
    final m1 = _mem('m1', '아들이 학교에서 발표를 했다', createdAt: DateTime(2026, 7, 1));
    final m2 = _mem('m2', '아들이 시험을 잘 봤다', createdAt: DateTime(2026, 7, 3));
    expect(extractMemoryEntities(m1, localeCode: 'ko').people, contains('아들'));
    expect(extractMemoryEntities(m2, localeCode: 'ko').people, contains('아들'));

    final cards = buildReplayInsightCards([m1, m2], localeCode: 'ko');

    if (cards.isEmpty) {
      fail(
        'expected cards; m1.people=${extractMemoryEntities(m1, localeCode: 'ko').people} '
        'm2.people=${extractMemoryEntities(m2, localeCode: 'ko').people}',
      );
    }
    expect(cards.every((c) => c.memoryCount >= kReplayInsightMinMemoryCount), isTrue);
    expect(cards.any((c) => c.title == '아들'), isTrue);
    expect(cards.any((c) => c.title == '나'), isFalse);
  });

  test('self person is not a replay insight pattern', () {
    final cards = buildReplayInsightCards(
      [
        _mem('m1', '오늘 산책을 했다', createdAt: DateTime(2026, 7, 1)),
        _mem('m2', '저녁을 먹었다', createdAt: DateTime(2026, 7, 2)),
      ],
      localeCode: 'ko',
    );
    expect(cards.any((c) => c.title == '나'), isFalse);
  });

  test('dedupes cards that point at the same memory set', () {
    final memories = [
      _mem('m1', '아들이 시험을 봤다', createdAt: DateTime(2026, 6, 1)),
      _mem('m2', '아들이 학교에 갔다', createdAt: DateTime(2026, 6, 2)),
    ];
    final cards = buildReplayInsightCards(memories, localeCode: 'ko');

    final keys = cards.map((c) => (c.memoryIds.toList()..sort()).join(',')).toSet();
    expect(keys.length, cards.length);
  });

  test('dedupeReplayInsightCards keeps person over event for same memory set', () {
    final sharedIds = {'m1', 'm2'};
    final deduped = dedupeReplayInsightCards([
      ReplayInsightCard(
        kind: ReplayInsightKind.event,
        title: '시험',
        subtitle: '관련 기억 2건',
        memoryCount: 2,
        focusKeyword: '시험',
        memoryIds: sharedIds,
      ),
      ReplayInsightCard(
        kind: ReplayInsightKind.person,
        title: '아들',
        subtitle: '함께한 기억 2건',
        memoryCount: 2,
        focusKeyword: '아들',
        memoryIds: sharedIds,
      ),
    ]);

    expect(deduped, hasLength(1));
    expect(deduped.single.kind, ReplayInsightKind.person);
    expect(deduped.single.title, '아들');
  });
}
