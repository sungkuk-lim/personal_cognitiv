import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'graph_fragment_freshness.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';
import 'memory_participation_extract.dart';
import 'memory_theme_tags.dart';

/// 관계망 위성 노드 — 사람·장소·조직·활동·감정.
class GraphMemorySatellites {
  const GraphMemorySatellites({
    this.people = const [],
    this.places = const [],
    this.organizations = const [],
    this.activities = const [],
    this.goals = const [],
    this.emotions = const [],
  });

  final List<String> people;
  final List<String> places;
  final List<String> organizations;
  final List<String> activities;
  final List<String> goals;
  final List<String> emotions;

  bool get isEmpty =>
      people.isEmpty &&
      places.isEmpty &&
      organizations.isEmpty &&
      activities.isEmpty &&
      goals.isEmpty &&
      emotions.isEmpty;
}

GraphMemorySatellites extractGraphSatellites(
  Memory memory, {
  required String localeCode,
  GraphMemoryFragment? aiFragment,
}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: aiFragment);
  final emotions = _emotionsFromMemory(memory);
  final goals = bundle.activities.isEmpty ? _goalsFromMemory(memory) : <String>[];

  return GraphMemorySatellites(
    people: bundle.people,
    places: bundle.places,
    organizations: bundle.organizations,
    activities: bundle.activities,
    goals: goals.take(1).toList(),
    emotions: emotions.take(1).toList(),
  );
}

/// 배지·위성 노드에 실제로 노출되는 위성만 반환 (허브 제목 중복·본인 제외).
GraphMemorySatellites visibleGraphSatellitesForMemory(
  Memory memory, {
  required String localeCode,
  GraphMemoryFragment? aiFragment,
  String? hubTitle,
}) {
  final fragment = freshGraphFragmentForMemory(memory, aiFragment);
  final resolvedHub = hubTitle?.trim().isNotEmpty == true
      ? hubTitle!.trim()
      : extractMemoryEntities(
          memory,
          localeCode: localeCode,
          aiFragment: fragment,
        ).eventTitle;

  final raw = extractGraphSatellites(memory, localeCode: localeCode, aiFragment: fragment);
  final people = peopleNotEmbeddedInPairActivities(
    raw.people.where((p) => !isSelfPersonLabel(p, localeCode)).toList(),
    raw.activities,
  ).where((p) => shouldShowGraphSatelliteLabel(p, hubTitle: resolvedHub)).toList();

  final places = raw.places
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .where((p) => shouldShowGraphSatelliteLabel(p, hubTitle: resolvedHub))
      .toList();

  List<String> filterMisc(List<String> labels) => labels
      .where((l) => !isGraphFoodOrNoiseToken(l))
      .where((l) => shouldShowGraphSatelliteLabel(l, hubTitle: resolvedHub))
      .toList();

  return GraphMemorySatellites(
    people: people,
    places: places,
    organizations: filterMisc(raw.organizations),
    activities: filterMisc(raw.activities),
    goals: filterMisc(raw.goals),
    emotions: filterMisc(raw.emotions),
  );
}

List<String> _emotionsFromMemory(Memory memory) {
  return emotionTagsForMemory(memory).take(2).toList();
}

List<String> _goalsFromMemory(Memory memory) {
  final content = memory.content.trim();
  final completed = RegExp(r'([가-힣A-Za-z0-9\s]{2,16})(?:을|를)\s*(?:완성|완료|달성)').firstMatch(content);
  if (completed != null) {
    final goal = completed.group(1)!.trim();
    if (goal.isNotEmpty) return [goal];
  }

  const hints = ['목표', '계획', '다짐', '완료', '완성', '성공'];
  for (final h in hints) {
    if (content.contains(h)) return [h];
  }
  return [];
}

bool shouldClaimSatelliteLabel(
  Map<String, String> claimed,
  String label,
  String kind,
) {
  final existing = claimed[label];
  if (existing == null) return true;
  return graphSatelliteLabelPriority(kind) < graphSatelliteLabelPriority(existing);
}

void claimSatelliteLabel(Map<String, String> claimed, String label, String kind) {
  claimed[label] = kind;
}

int graphSatelliteLabelPriority(String kind) {
  return switch (kind) {
    'person' => 0,
    'place' => 1,
    'organization' => 2,
    'activity' => 3,
    'goal' => 4,
    'emotion' => 5,
    _ => 6,
  };
}

/// 「철수와 민수」 같은 사람-사람 활동에 이미 포함된 인물은 별도 위성에서 제외.
List<String> peopleNotEmbeddedInPairActivities(List<String> people, List<String> activities) {
  final embedded = <String>{};
  final pairRe = RegExp(r'^([가-힣]{2,8})와\s+([가-힣]{2,8})$');
  for (final activity in activities) {
    final m = pairRe.firstMatch(activity.trim());
    if (m == null) continue;
    final left = normalizeKoreanPersonName(m.group(1)!);
    final right = normalizeKoreanPersonName(m.group(2)!);
    if (isGraphVenueToken(right) || isGraphFoodOrNoiseToken(right) || isGraphMealCompanionToken(right)) {
      continue;
    }
    if (!isFamilyRelationTerm(left) && !isLikelyKoreanPersonName(left)) continue;
    if (!isFamilyRelationTerm(right) && !isLikelyKoreanPersonName(right)) continue;
    embedded.add(left);
    embedded.add(right);
  }
  if (embedded.isEmpty) return people;
  return people
      .where((p) => !embedded.contains(normalizeKoreanPersonName(stripTrailingKoreanParticles(p))))
      .toList();
}
