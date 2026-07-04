import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/local_memory_store.dart';

void main() {
  final junkPhoto = Memory(
    id: '1',
    content: '기기에 저장된 사진',
    summary: '기기에 저장된 사진',
    entities: const [],
    createdAt: DateTime(2026, 6, 10),
    type: 'image',
    isLocalOnly: true,
  );
  final goodPhoto = Memory(
    id: '2',
    content: '광안리 해수욕장',
    summary: '광안리 해수욕장 · 6월 16일 14:30',
    entities: const ['광안리'],
    createdAt: DateTime(2026, 6, 16),
    type: 'image',
    isLocalOnly: true,
  );
  final voice = Memory(
    id: '3',
    content: '오늘 사진 찍었다',
    summary: '음성',
    entities: const [],
    createdAt: DateTime(2026, 6, 17),
    type: 'voice',
    isLocalOnly: true,
  );

  test('isPhotoSearchQuery detects photo keywords', () {
    expect(isPhotoSearchQuery('사진'), isTrue);
    expect(isPhotoSearchQuery('photo'), isTrue);
    expect(isPhotoSearchQuery('광안리'), isFalse);
  });

  test('searchLocalMemories returns image memories for photo query', () {
    final results = searchLocalMemories([junkPhoto, goodPhoto, voice], '사진');
    expect(results.length, 2);
    expect(results.every((m) => m.type == 'image'), isTrue);
  });

  test('searchResultTitle avoids junk photo summary', () {
    expect(searchResultTitle(goodPhoto), contains('광안리'));
  });
}
