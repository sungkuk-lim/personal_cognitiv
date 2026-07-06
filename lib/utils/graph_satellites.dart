import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'graph_fragment_freshness.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';
import 'memory_participation_extract.dart';
import 'memory_semantic_extract.dart';
import 'memory_theme_tags.dart';

/// 관계망 위성 노드 — 사람·장소·조직·활동·이벤트·콘텐츠·관심사·음식·취미·감정.
class GraphMemorySatellites {
  const GraphMemorySatellites({
    this.people = const [],
    this.places = const [],
    this.organizations = const [],
    this.activities = const [],
    this.events = const [],
    this.contents = const [],
    this.interests = const [],
    this.food = const [],
    this.hobbies = const [],
    this.goals = const [],
    this.emotions = const [],
  });

  final List<String> people;
  final List<String> places;
  final List<String> organizations;
  final List<String> activities;
  final List<String> events;
  final List<String> contents;
  final List<String> interests;
  final List<String> food;
  final List<String> hobbies;
  final List<String> goals;
  final List<String> emotions;

  bool get isEmpty =>
      people.isEmpty &&
      places.isEmpty &&
      organizations.isEmpty &&
      activities.isEmpty &&
      events.isEmpty &&
      contents.isEmpty &&
      interests.isEmpty &&
      food.isEmpty &&
      hobbies.isEmpty &&
      goals.isEmpty &&
      emotions.isEmpty;
}

GraphMemorySatellites extractGraphSatellites(
  Memory memory, {
  required String localeCode,
  GraphMemoryFragment? aiFragment,
}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: aiFragment);
  final activities = [...bundle.activities];
  if (bundle.events.contains('여행') && !activities.contains('여행')) {
    activities.add('여행');
  }
  final emotions = _dedupeOrdered([
    ..._emotionsFromMemory(memory),
    ...bundle.emotions,
  ]);
  final goals = bundle.activities.isEmpty ? _goalsFromMemory(memory) : <String>[];

  return GraphMemorySatellites(
    people: bundle.people,
    places: bundle.places,
    organizations: bundle.organizations,
    activities: activities,
    events: bundle.events,
    contents: bundle.contents,
    interests: bundle.interests,
    food: bundle.food,
    hobbies: bundle.hobbies,
    goals: goals.take(1).toList(),
    emotions: emotions.take(2).toList(),
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
    raw.people
        .where((p) => !isSelfPersonLabel(p, localeCode) && !isNonPersonGraphToken(p))
        .where((p) => !isGraphMorphologyJunkToken(p))
        .toList(),
    raw.activities,
  ).where((p) => shouldShowGraphSatelliteLabel(p, hubTitle: resolvedHub)).toList();

  final places = raw.places
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .where((p) => !isGraphMorphologyJunkToken(p) && !isMisleadingPlaceChonToken(p))
      .where((p) => shouldShowGraphSatelliteLabel(p, hubTitle: resolvedHub))
      .toList();

  List<String> filterMisc(List<String> labels) => labels
      .where((l) => !isGraphFoodOrNoiseToken(l))
      .where((l) => shouldShowGraphSatelliteLabel(l, hubTitle: resolvedHub))
      .toList();

  return consolidateVisibleGraphSatellites(
    GraphMemorySatellites(
      people: people,
      places: places,
      organizations: filterMisc(raw.organizations),
      activities: filterMisc(raw.activities),
      events: filterMisc(raw.events),
      contents: filterMisc(raw.contents),
      interests: filterMisc(raw.interests),
      food: raw.food
          .where((l) => !isGraphFoodOrNoiseToken(l))
          .where((l) => shouldShowGraphSatelliteLabel(l, hubTitle: resolvedHub))
          .toList(),
      hobbies: filterMisc(raw.hobbies),
      goals: filterMisc(raw.goals),
      emotions: filterMisc(raw.emotions),
    ),
    hubTitle: resolvedHub,
  );
}

/// 관계망 위성 — 이벤트·활동·관심사 중복 제거, 대표 이벤트 1개 우선.
GraphMemorySatellites consolidateVisibleGraphSatellites(
  GraphMemorySatellites raw, {
  required String hubTitle,
}) {
  final hub = hubTitle.trim();
  final primaryEvent = _pickPrimaryGraphEvent([...raw.events, if (hub.contains('시험')) hub]);

  bool subsumedByEvent(String label) {
    if (primaryEvent == null) return false;
    final v = label.trim();
    if (v.isEmpty) return true;
    if (v == primaryEvent) return true;
    if (primaryEvent.contains(v)) return true;
    if (v.contains('시험') && primaryEvent.contains('시험')) return true;
    return false;
  }

  final events = primaryEvent == null
      ? raw.events.take(1).toList()
      : [primaryEvent];

  final activities = raw.activities.where((a) => !subsumedByEvent(a)).take(2).toList();
  final interests = raw.interests.where((i) => !subsumedByEvent(i) && !hub.contains(i)).toList();

  final hobbies = raw.hobbies.where((h) => !raw.contents.contains(h)).toList();

  return GraphMemorySatellites(
    people: raw.people,
    places: raw.places,
    organizations: raw.organizations,
    activities: activities,
    events: events,
    contents: raw.contents,
    interests: interests,
    food: raw.food,
    hobbies: hobbies,
    goals: raw.goals,
    emotions: raw.emotions,
  );
}

String? _pickPrimaryGraphEvent(List<String> candidates) {
  final cleaned = candidates.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  if (cleaned.isEmpty) return null;
  cleaned.sort((a, b) {
    final aScore = (a.contains('시험') ? 100 : 0) + a.length;
    final bScore = (b.contains('시험') ? 100 : 0) + b.length;
    return bScore.compareTo(aScore);
  });
  return cleaned.first;
}

List<String> _dedupeOrdered(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    final key = item.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(key);
  }
  return out;
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
    'event' => 3,
    'activity' => 4,
    'content' => 5,
    'interest' => 6,
    'food' => 7,
    'hobby' => 8,
    'goal' => 9,
    'emotion' => 10,
    _ => 11,
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
