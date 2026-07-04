import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/utils/entity_canonical.dart';
import 'package:personal_cognitive/utils/memory_entity_extract.dart';
import 'package:personal_cognitive/utils/memory_graph_semantics.dart';

Memory _mem(String content, {List<String> entities = const []}) {
  return Memory(
    id: '1',
    userId: 'u',
    content: content,
    summary: content,
    entities: entities,
    createdAt: DateTime(2026, 6, 10),
    isLocalOnly: true,
  );
}

void main() {
  test('canonicalEntityLabel merges 엄마 and 어머니', () {
    expect(canonicalEntityLabel('엄마'), '어머니');
    expect(canonicalEntityLabel('어머니'), '어머니');
  });

  test('extractRelationsFromMemory finds 동행 and 방문', () {
    final m = _mem('어머니와 광안리해수욕장에 가서 회를 먹었다.');
    final rels = extractRelationsFromMemory(m);
    expect(rels.any((r) => r.predicate == '동행' && r.object == '어머니'), isTrue);
    expect(rels.any((r) => r.predicate == '방문'), isTrue);
  });

  test('enrichMemoryGraphSemantics adds event, time, importance, relations', () {
    final enriched = enrichMemoryGraphSemantics(
      _mem('어머니와 부산 여행에서 행복한 저녁 식사'),
    );
    expect(enriched.entities.any((e) => e.startsWith('rel:')), isTrue);
    expect(enriched.entities.any((e) => e.startsWith('event:')), isTrue);
    expect(enriched.entities.any((e) => e.startsWith('time:year:')), isTrue);
    expect(enriched.entities.any((e) => e.startsWith('importance:')), isTrue);
    expect(importanceForMemory(enriched), greaterThanOrEqualTo(2));
  });

  test('MemoryRelation round-trip entity tag', () {
    const rel = MemoryRelation(predicate: '동행', object: '어머니');
    final parsed = MemoryRelation.fromEntityTag(rel.toEntityTag());
    expect(parsed?.predicate, '동행');
    expect(parsed?.object, '어머니');
  });

  test('shouldShowGraphSatelliteLabel rejects rel tags and composites', () {
    expect(shouldShowGraphSatelliteLabel('rel:방문:카페'), isFalse);
    expect(shouldShowGraphSatelliteLabel('철수와 카페'), isFalse);
    expect(shouldShowGraphSatelliteLabel('철수'), isTrue);
    expect(shouldShowGraphSatelliteLabel('카페'), isTrue);
  });

  test('eventGroupKeyForMemory merges same title across dates', () {
    final bundle = extractMemoryEntities(
      _mem('철수와 카페에서 3시간 이야기.'),
    );
    final keyA = eventGroupKeyForMemory(
      memory: _mem('철수와 카페에서 3시간 이야기.').copyWith(createdAt: DateTime(2026, 5, 1)),
      bundle: bundle,
    );
    final keyB = eventGroupKeyForMemory(
      memory: _mem('철수와 카페에서 3시간 이야기.').copyWith(createdAt: DateTime(2026, 6, 1)),
      bundle: bundle,
    );
    expect(keyA, keyB);
  });
}
