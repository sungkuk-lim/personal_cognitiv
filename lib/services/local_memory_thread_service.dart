import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../utils/entity_canonical.dart';
import '../utils/memory_entity_extract.dart';
import '../utils/memory_graph_semantics.dart';
import '../utils/memory_keyword_ui.dart';
import '../utils/memory_participation_extract.dart';
import '../utils/embedding_utils.dart';

/// Pro·클라oud 없이도 연관 기억을 찾습니다 (사람·장소·같은 날·관계·키워드).
class LocalMemoryThreadService {
  LocalMemoryThreadService._();

  static List<Memory> findRelated({
    required Memory saved,
    required List<Memory> allMemories,
    String? excludeId,
    int limit = 3,
    String localeCode = 'ko',
  }) {
    final exclude = excludeId ?? saved.id;
    final candidates = allMemories
        .where(isUserFacingMemory)
        .where((m) => m.id != exclude)
        .toList();
    if (candidates.isEmpty) return const [];

    final bundleSaved = extractMemoryEntities(saved, localeCode: localeCode);
    final peopleSaved = bundleSaved.people
        .where((p) => !isSelfPersonLabel(p, localeCode))
        .map((p) => canonicalEntityLabel(p, localeCode: localeCode))
        .toSet();
    final placesSaved = bundleSaved.places.map((p) => p.trim()).where((p) => p.isNotEmpty).toSet();
    final daySaved = _dayKey(saved.createdAt);
    final relSaved = relationsForMemory(saved)
        .map((r) => '${r.predicate}::${canonicalEntityLabel(r.object)}')
        .toSet();

    final scored = <({Memory memory, int score})>[];
    for (final other in candidates) {
      var score = 0;
      final bundleOther = extractMemoryEntities(other, localeCode: localeCode);

      for (final person in bundleOther.people) {
        if (isSelfPersonLabel(person, localeCode)) continue;
        final canonical = canonicalEntityLabel(person, localeCode: localeCode);
        if (peopleSaved.contains(canonical)) score += 55;
      }

      for (final place in bundleOther.places) {
        if (placesSaved.contains(place.trim())) score += 48;
      }

      if (_dayKey(other.createdAt) == daySaved) score += 38;

      for (final rel in relationsForMemory(other)) {
        final key = '${rel.predicate}::${canonicalEntityLabel(rel.object)}';
        if (relSaved.contains(key)) score += 32;
      }

      final hubA = eventHubForMemory(saved)?.id;
      final hubB = eventHubForMemory(other)?.id;
      if (hubA != null && hubA == hubB) score += 42;

      for (final label in userVisibleEntityLabels(saved, localeCode: localeCode)) {
        if (label.length < 2) continue;
        if (memoryMatchesKeyword(other, label, localeCode: localeCode)) {
          score += 28;
        }
      }

      if (saved.embedding != null &&
          other.embedding != null &&
          embeddingsAreSimilar(saved.embedding, other.embedding)) {
        score += 62;
      }

      if (score > 0) {
        scored.add((memory: other, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.memory.createdAt.compareTo(a.memory.createdAt);
    });

    return scored.take(limit).map((e) => e.memory).toList();
  }

  static String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
}
