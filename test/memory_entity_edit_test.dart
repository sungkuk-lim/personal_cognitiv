import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/memory_entity_edit.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';

Memory _memory() => Memory(
      id: 'm1',
      content: '민수와 카페에서 이야기',
      summary: '카페',
      entities: ['철수', 'rel:동행:카페', 'tag:activity:카페'],
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  test('mergeManualEntityLabels keeps internal tags and manual flag', () {
    final merged = mergeManualEntityLabels(_memory(), ['민수', '카페']);
    expect(merged, containsAll(['민수', '카페', kTagEntitiesManual, 'rel:동행:카페']));
    expect(merged, isNot(contains('철수')));
  });

  test('enrichMemoryGraphSemantics preserves manual visible labels', () {
    final manual = mergeManualEntityLabels(_memory(), ['민수', '카페']);
    final enriched = enrichMemoryGraphSemantics(_memory().copyWith(entities: manual), localeCode: 'ko');
    expect(memoryHasManualEntityEdit(enriched), isTrue);
    expect(editableEntityLabelsForMemory(enriched), containsAll(['민수', '카페']));
    expect(editableEntityLabelsForMemory(enriched), isNot(contains('철수')));
  });
}
