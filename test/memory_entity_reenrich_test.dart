import 'package:flutter_test/flutter_test.dart';
import 'package:personal_cognitive/models/memory.dart';
import 'package:personal_cognitive/services/local_memory_store.dart';
import 'package:personal_cognitive/services/memory_entity_reenrich_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Memory _mem({
  required String id,
  required String content,
  List<String> entities = const [],
}) {
  return Memory(
    id: id,
    userId: 'u',
    content: content,
    summary: content,
    entities: entities,
    createdAt: DateTime(2026, 6, 10),
    isLocalOnly: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reenrichLocalMemoriesIfNeeded strips stale entities', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalMemoryStore(prefs);
    final polluted = _mem(
      id: '1',
      content: '민수와 카페에서 이야기',
      entities: ['철수', 'rel:동행:철수', '카페'],
    );
    await store.saveAll([polluted]);

    final result = await reenrichLocalMemoriesIfNeeded(
      store: store,
      prefs: prefs,
      memories: [polluted],
      localeCode: 'ko',
    );

    expect(result.updatedCount, 1);
    expect(result.memories.first.entities, isNot(contains('철수')));
    expect(result.memories.first.entities.any((e) => e.startsWith('rel:동행:철수')), isFalse);
    final reloaded = store.loadAll();
    expect(reloaded.first.entities, isNot(contains('철수')));
  });
}
