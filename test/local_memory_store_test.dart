import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal_cognitive/core/prefs.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/local_memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocalMemoryStore insert and delete', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalMemoryStore(prefs);

    final memory = Memory(
      id: 'test-1',
      content: '테스트 기억',
      summary: '테스트',
      entities: const ['카페'],
      createdAt: DateTime(2024, 1, 1),
      isLocalOnly: true,
    );

    await store.insert(memory);
    expect(store.loadAll().length, 1);
    expect(store.loadAll().first.content, '테스트 기억');

    final deleted = await store.delete('test-1');
    expect(deleted, isTrue);
    expect(store.loadAll(), isEmpty);
  });

  test('searchLocalMemories finds by keyword', () {
    final memories = [
      Memory(id: '1', content: '제주도 여행', summary: '제주도', entities: const [], createdAt: DateTime.now(), isLocalOnly: true),
      Memory(id: '2', content: '회의', summary: '업무', entities: const [], createdAt: DateTime.now(), isLocalOnly: true),
    ];
    final results = searchLocalMemories(memories, '제주');
    expect(results.length, 1);
    expect(results.first.id, '1');
  });

  test('LocalMemoryStore assigns id when empty', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalMemoryStore(prefs);

    final memory = Memory(
      id: '',
      content: '빈 ID 기억',
      summary: '요약',
      entities: const [],
      createdAt: DateTime.now(),
      isLocalOnly: true,
    );

    final saved = await store.insert(memory);
    expect(saved.id, isNotEmpty);
    expect(store.loadAll().length, 1);
    expect(store.loadAll().first.id, saved.id);
  });

  test('readPrivacyLocalMode and guest mode prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(readPrivacyLocalMode(prefs), isFalse);
    await writePrivacyLocalMode(prefs, true);
    expect(readPrivacyLocalMode(prefs), isTrue);
    await writeGuestMode(prefs, true);
    expect(readGuestMode(prefs), isTrue);
  });
}
