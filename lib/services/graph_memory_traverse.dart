import '../models/memory.dart';
import '../utils/memory_entity_extract.dart';
import '../utils/memory_keyword_ui.dart';
import '../utils/entity_canonical.dart';
import '../utils/memory_graph_semantics.dart';
import '../utils/memory_theme_tags.dart';
import '../utils/memory_query.dart';

/// Phase C — 엔티티 공유로 연결된 기억을 BFS로 확장합니다.
///
/// [maxDepth] 기본 5: 나→1차→…→5차까지 기억 묶음을 따라갈 수 있습니다.
/// (화면의 허브·위성 UI와 달리, 검색·답변용 **기억 간 hop** 깊이입니다.)
List<Memory> traverseGraphForQuery({
  required List<Memory> memories,
  required MemoryQuery query,
  String localeCode = 'ko',
  int limit = 24,
  int maxDepth = 5,
}) {
  if (memories.isEmpty || query.isEmpty) return [];

  final seeds = memories
      .where((m) => memoryMatchesQuery(m, query, localeCode: localeCode))
      .take(4)
      .toList();
  if (seeds.isEmpty) {
    for (final person in query.people) {
      seeds.addAll(memories.where((m) => memoryMatchesKeyword(m, person, localeCode: localeCode)).take(2));
    }
    for (final place in query.places) {
      seeds.addAll(memories.where((m) => memoryMatchesKeyword(m, place, localeCode: localeCode)).take(2));
    }
  }
  if (seeds.isEmpty) return [];

  final byId = {for (final m in memories) m.id: m};
  final adjacency = <String, Set<String>>{};
  void link(String a, String b) {
    if (a == b) return;
    adjacency.putIfAbsent(a, () => {}).add(b);
    adjacency.putIfAbsent(b, () => {}).add(a);
  }

  for (var i = 0; i < memories.length; i++) {
    for (var j = i + 1; j < memories.length; j++) {
      final a = memories[i];
      final b = memories[j];
      if (_shareEntity(a, b, localeCode)) link(a.id, b.id);
    }
  }

  final visited = <String>{};
  final queue = <(String id, int depth)>[];
  for (final s in seeds) {
    queue.add((s.id, 0));
    visited.add(s.id);
  }

  final ordered = <Memory>[];
  while (queue.isNotEmpty && ordered.length < limit) {
    final (id, depth) = queue.removeAt(0);
    final memory = byId[id];
    if (memory != null) ordered.add(memory);
    if (depth >= maxDepth) continue;
    for (final next in adjacency[id] ?? const {}) {
      if (visited.add(next)) queue.add((next, depth + 1));
    }
  }

  return ordered;
}

bool _shareEntity(Memory a, Memory b, String localeCode) {
  final bundleA = extractMemoryEntities(a, localeCode: localeCode);
  final bundleB = extractMemoryEntities(b, localeCode: localeCode);

  bool overlap(Iterable<String> x, Iterable<String> y) {
    final setY = y.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    for (final item in x) {
      if (setY.contains(item.trim())) return true;
    }
    return false;
  }

  if (overlap(bundleA.people, bundleB.people)) return true;
  if (overlap(bundleA.places, bundleB.places)) return true;
  if (overlap(emotionTagsForMemory(a), emotionTagsForMemory(b))) return true;
  if (overlap(activityTagsForMemory(a), activityTagsForMemory(b))) return true;
  if (overlap(foodTagsForMemory(a), foodTagsForMemory(b))) return true;
  for (final relA in relationsForMemory(a)) {
    for (final relB in relationsForMemory(b)) {
      if (relA.predicate == relB.predicate &&
          canonicalEntityLabel(relA.object) == canonicalEntityLabel(relB.object)) {
        return true;
      }
    }
  }
  if (eventHubForMemory(a)?.id == eventHubForMemory(b)?.id &&
      eventHubForMemory(a) != null) {
    return true;
  }
  return false;
}
