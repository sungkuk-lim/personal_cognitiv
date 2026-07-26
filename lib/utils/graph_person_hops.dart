import '../models/memory.dart';
import 'entity_canonical.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';

bool _isHopPersonLabel(String raw) {
  final c = canonicalEntityLabel(raw).trim();
  if (c.isEmpty) return false;
  if (c.contains(':')) return false; // rel: tag: flow: …
  if (isBlockedPersonName(c)) return false;
  if (isLikelyKoreanPersonName(c) || isPersonLabelNotPlace(c)) return true;
  // 영문·기타 수동 인명
  if (RegExp(r'^[A-Za-z][A-Za-z ._-]{1,40}$').hasMatch(c)) return true;
  return false;
}

/// 한 기억에 등장한 사람 라벨 (hop 계산용 — 장소·활동 혼입 최소화).
Set<String> peopleLabelsForHop(Memory memory, {required String localeCode}) {
  final out = <String>{};
  for (final e in memory.entities) {
    if (_isHopPersonLabel(e)) out.add(canonicalEntityLabel(e));
  }
  // entities가 비어 있을 때만 추출기 보조
  if (out.length < 2) {
    for (final p in extractMemoryEntities(memory, localeCode: localeCode).people) {
      final c = canonicalEntityLabel(p);
      if (c.isNotEmpty && !isBlockedPersonName(c)) out.add(c);
    }
  }
  return out;
}

/// 사람↔사람 hop 거리 (같은 기억에 함께 등장 = 1 hop).
///
/// 이론의 5차 관계망에 대응하는 **앱 내부 지표**입니다.
Map<String, int> personHopDistances({
  required String fromPerson,
  required List<Memory> memories,
  required String localeCode,
  int maxDepth = 5,
}) {
  final from = canonicalEntityLabel(fromPerson).trim();
  if (from.isEmpty || memories.isEmpty) return {};

  final adjacency = <String, Set<String>>{};
  void link(String a, String b) {
    if (a == b) return;
    adjacency.putIfAbsent(a, () => {}).add(b);
    adjacency.putIfAbsent(b, () => {}).add(a);
  }

  var sawFrom = false;
  for (final memory in memories) {
    final people = peopleLabelsForHop(memory, localeCode: localeCode);
    if (people.contains(from)) sawFrom = true;
    if (people.length < 2) continue;
    final list = people.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        link(list[i], list[j]);
      }
    }
  }

  if (!sawFrom && !adjacency.containsKey(from)) return {};

  final dist = <String, int>{from: 0};
  final queue = <String>[from];
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    final d = dist[cur]!;
    if (d >= maxDepth) continue;
    for (final next in adjacency[cur] ?? const {}) {
      if (dist.containsKey(next)) continue;
      dist[next] = d + 1;
      queue.add(next);
    }
  }

  dist.remove(from);
  return dist;
}

/// hop 거리별 인물 목록 (1차→5차).
Map<int, List<String>> groupPeopleByHop(Map<String, int> distances) {
  final out = <int, List<String>>{};
  for (final e in distances.entries) {
    out.putIfAbsent(e.value, () => []).add(e.key);
  }
  for (final list in out.values) {
    list.sort();
  }
  return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}
