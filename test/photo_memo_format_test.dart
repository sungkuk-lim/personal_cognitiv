import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/utils/photo_memo_format.dart';
import 'package:personal_cognitive/utils/photo_memory_format.dart';
import 'package:personal_cognitive/models/memory.dart';

void main() {
  test('enrichPhotoFieldsWithUserMemo keeps title and merges entities only', () {
    final base = buildPhotoMemoryFieldsLocal(
      capturedAt: DateTime(2026, 6, 16, 15, 0),
      localeCode: 'ko',
      gpsPlace: '부산',
    );

    final enriched = enrichPhotoFieldsWithUserMemo(
      fields: base,
      userMemo: '광안리 해수욕장에서 민수랑 놀았다',
      capturedAt: DateTime(2026, 6, 16, 15, 0),
      localeCode: 'ko',
      gpsPlace: '부산',
    );

    expect(enriched.entities, contains('민수'));
    expect(enriched.entities.any((e) => e.contains('광안리')), isTrue);
    expect(enriched.summary, base.summary);
    expect(enriched.content, base.content);
  });

  test('mergeEntitiesFromPhotoMemo updates entities without userMemo', () {
    final memory = Memory(
      id: '1',
      content: '사진',
      summary: '광안리 · 6월 16일',
      entities: const ['광안리'],
      createdAt: DateTime.now(),
      type: 'image',
    );

    final merged = mergeEntitiesFromPhotoMemo(memory, '철수와 함께');
    expect(merged.entities, contains('철수'));
    expect(merged.userMemo, isEmpty);
    expect(merged.content, memory.content);
  });

  test('mergeMemoIntoMemory updates entities', () {
    final memory = Memory(
      id: '1',
      content: '사진',
      summary: '광안리 · 6월 16일',
      entities: const ['광안리'],
      createdAt: DateTime.now(),
      type: 'image',
      userMemo: '광안리',
    );

    final merged = mergeMemoIntoMemory(memory, additionalMemo: '철수와 함께');
    expect(merged.entities, contains('철수'));
    expect(merged.userMemo, contains('철수'));
  });
}
