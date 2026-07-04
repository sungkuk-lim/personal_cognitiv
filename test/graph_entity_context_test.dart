import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/graph_entity_context.dart';

void main() {
  test('GraphEntityContext badge matches visible satellites only', () {
    final memory = Memory(
      id: 'm1',
      content: '영희와 카페에서 3시간 이야기',
      summary: '영희와 카페에서 3시간 이야기',
      entities: const ['영희', '카페'],
      createdAt: DateTime(2026, 7, 3),
    );
    final ctx = GraphEntityContext.forMemory(memory, localeCode: 'ko');
    expect(ctx.badgeText, isNull);
    expect(ctx.visibleSatellites.people, isEmpty);
    expect(ctx.visibleSatellites.places, isEmpty);
  });

  test('GraphEntityContext keeps family satellite with badge', () {
    final memory = Memory(
      id: 'd1',
      content: '아들과 집에서 저녁식사 함께함',
      summary: '아들과 집에서 저녁식사 함께함',
      entities: const ['아들'],
      createdAt: DateTime(2026, 7, 3),
    );
    final ctx = GraphEntityContext.forMemory(memory, localeCode: 'ko');
    expect(ctx.visibleSatellites.people, contains('아들'));
    expect(ctx.badgeText, contains('사람 1'));
  });
}
