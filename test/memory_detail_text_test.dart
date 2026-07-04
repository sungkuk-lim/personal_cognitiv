import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_detail_text.dart';

void main() {
  test('hides duplicate summary title when body starts with same line', () {
    const summary = '대호의 행동이 너무 이상했다.';
    const body = '''대호의 행동이 너무 이상했다
많은 의문을 남긴다,
아직도 그날에 어떤 일이 있었는지 모른다..''';

    expect(
      shouldShowMemoryDetailSummaryTitle(summaryTitle: summary, bodyText: body),
      isFalse,
    );
    expect(memoryTextsOverlapForDisplay(summary, body), isTrue);
  });

  test('shows summary title when it adds distinct headline', () {
    const summary = '연숙 실종으로 여행이 엉망이 됐어.';
    const body = '''6월 18일 해순, 은정, 연숙, 재운, 대호 이렇게 나를 포함해서 6명이 부산 광안리 해수욕장에 여행을 했어
18일 밤 11시쯤 연숙이가 없어져서 여행이 엉망이 됐어.''';

    expect(
      shouldShowMemoryDetailSummaryTitle(summaryTitle: summary, bodyText: body),
      isTrue,
    );
  });

  test('memoryDetailDisplayBody prefers full content', () {
    final memory = Memory(
      id: '1',
      content: '대호의 행동이 너무 이상했다.\n많은 의문을 남긴다.',
      summary: '대호의 행동이 너무 이상했다.',
      entities: const [],
      createdAt: DateTime(2026, 6, 18),
    );

    expect(memoryDetailDisplayBody(memory), memory.content.trim());
  });
}
