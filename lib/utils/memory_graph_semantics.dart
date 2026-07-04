import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'entity_canonical.dart';
import 'memory_entity_extract.dart';
import 'memory_theme_tags.dart';

/// 관계: rel:{predicate}:{object} 또는 rel:{subject}:{predicate}:{object}
const String kRelPrefix = 'rel:';
const String kEventPrefix = 'event:';
const String kTimePrefix = 'time:';
const String kImportancePrefix = 'importance:';

const kRelationPredicates = {
  '동행': ['함께', '같이', '동행', '와', '과'],
  '방문': ['방문', '갔', '다녀', '여행', '도착'],
  '식사': ['식사', '먹', '저녁', '점심', '아침', '식당'],
  '촬영': ['사진', '촬영', '찍', '셀카'],
  '대화': ['이야기', '대화', '얘기', '수다'],
  '운전': ['운전', '드라이브', '차로'],
  '축하': ['축하', '생일', '기념'],
  '도움': ['도움', '도와', '부탁'],
  '공부': ['공부', '학습', '수업'],
  '운동': ['운동', '달리', '헬스', '수영'],
};

const kLifeEventKeywords = {
  '결혼': 5,
  '출생': 5,
  '돌잔치': 5,
  '졸업': 4,
  '입학': 4,
  '승진': 4,
  '여행': 3,
  '장례': 5,
  '이사': 3,
  '프로포즈': 5,
};

class MemoryRelation {
  const MemoryRelation({
    required this.predicate,
    required this.object,
    this.subject = '나',
  });

  final String subject;
  final String predicate;
  final String object;

  String toEntityTag() {
    final obj = canonicalEntityLabel(object);
    final sub = canonicalEntityLabel(subject);
    if (sub == '나' || sub.isEmpty) return '$kRelPrefix$predicate:$obj';
    return '$kRelPrefix$sub:$predicate:$obj';
  }

  static MemoryRelation? fromEntityTag(String tag) {
    if (!tag.startsWith(kRelPrefix)) return null;
    final body = tag.substring(kRelPrefix.length);
    final parts = body.split(':');
    if (parts.length == 2) {
      return MemoryRelation(predicate: parts[0], object: parts[1]);
    }
    if (parts.length >= 3) {
      return MemoryRelation(subject: parts[0], predicate: parts[1], object: parts.sublist(2).join(':'));
    }
    return null;
  }
}

class MemoryEventHub {
  const MemoryEventHub({required this.id, required this.title});

  final String id;
  final String title;

  String toEntityTag() => '$kEventPrefix$id:$title';

  static MemoryEventHub? fromEntityTag(String tag) {
    if (!tag.startsWith(kEventPrefix)) return null;
    final body = tag.substring(kEventPrefix.length);
    final sep = body.indexOf(':');
    if (sep <= 0) return null;
    return MemoryEventHub(
      id: body.substring(0, sep),
      title: body.substring(sep + 1),
    );
  }
}

List<MemoryRelation> relationsForMemory(Memory memory) {
  return memory.entities
      .map(MemoryRelation.fromEntityTag)
      .whereType<MemoryRelation>()
      .toList();
}

MemoryEventHub? eventHubForMemory(Memory memory) {
  for (final e in memory.entities) {
    final hub = MemoryEventHub.fromEntityTag(e);
    if (hub != null) return hub;
  }
  return null;
}

int importanceForMemory(Memory memory) {
  for (final e in memory.entities) {
    if (e.startsWith(kImportancePrefix)) {
      final n = int.tryParse(e.substring(kImportancePrefix.length));
      if (n != null && n >= 1 && n <= 5) return n;
    }
  }
  return _inferImportance(memory);
}

List<String> timeFacetsForMemory(Memory memory) {
  return memory.entities.where((e) => e.startsWith(kTimePrefix)).toList();
}

String eventHubIdFromTitle(String title, DateTime at) {
  final slug = eventSlugFromTitle(title);
  return '${at.year}-${at.month.toString().padLeft(2, '0')}-$slug';
}

/// 이벤트 허브 묶음 키 — 같은 사건 제목은 하나의 허브로 (월·태그 ID 차이 무시).
String normalizeEventTitle(String raw) {
  return raw.trim().replaceAll(RegExp(r'[.…\s]+$'), '').replaceAll(RegExp(r'\s+'), ' ');
}

String eventSlugFromTitle(String title) {
  final slug = normalizeEventTitle(title)
      .replaceAll(RegExp(r'[^\w가-힣]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'moment' : slug;
}

String eventGroupKeyForMemory({
  required Memory memory,
  required MemoryEntityBundle bundle,
  MemoryEventHub? storedHub,
  String localeCode = 'ko',
}) {
  final title = normalizeEventTitle(
    storedHub?.title ??
        (bundle.eventTitle.isNotEmpty
            ? bundle.eventTitle
            : (memory.summary.trim().isNotEmpty ? memory.summary : memory.content)),
  );

  if (title.isNotEmpty && bundle.hasEventHub) {
    return 'title::${eventSlugFromTitle(title)}';
  }

  final d = memory.createdAt;
  return 'day::${d.year}-${d.month}-${d.day}';
}

List<MemoryRelation> extractRelationsFromMemory(Memory memory, {String localeCode = 'ko'}) {
  final text = '${memory.content}\n${memory.summary}\n${memory.userMemo}';
  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  final relations = <MemoryRelation>[];

  for (final person in bundle.people) {
    final p = canonicalEntityLabel(person);
    if (p.isEmpty || p == '나') continue;
    if (text.contains('함께') || text.contains('같이') || RegExp('(?:와|과)\\s*$p').hasMatch(text)) {
      relations.add(MemoryRelation(predicate: '동행', object: p));
    } else if (text.contains(p)) {
      relations.add(MemoryRelation(predicate: '동행', object: p));
    }
  }

  for (final place in bundle.places) {
    final pl = canonicalEntityLabel(place);
    if (pl.isEmpty) continue;
    relations.add(MemoryRelation(predicate: '방문', object: pl));
  }

  for (final food in foodTagsForMemory(memory)) {
    relations.add(MemoryRelation(predicate: '식사', object: food));
  }

  for (final emotion in emotionTagsForMemory(memory, localeCode: localeCode)) {
    relations.add(MemoryRelation(predicate: '감정', object: emotion));
  }

  if (memory.type == 'image' || text.contains('사진') || text.contains('촬영')) {
    for (final place in bundle.places.take(1)) {
      relations.add(MemoryRelation(predicate: '촬영', object: canonicalEntityLabel(place)));
    }
  }

  for (final activity in bundle.activities) {
    for (final entry in kRelationPredicates.entries) {
      if (entry.key == '동행' || entry.key == '방문' || entry.key == '식사') continue;
      if (entry.value.any((w) => activity.contains(w) || text.contains(w))) {
        relations.add(MemoryRelation(predicate: entry.key, object: activity));
      }
    }
  }

  return _dedupeRelations(relations);
}

List<MemoryRelation> _dedupeRelations(List<MemoryRelation> items) {
  final seen = <String>{};
  final out = <MemoryRelation>[];
  for (final r in items) {
    final key = r.toEntityTag();
    if (seen.add(key)) out.add(r);
  }
  return out;
}

List<String> _timeFacetTags(DateTime at, {String localeCode = 'ko'}) {
  final month = at.month;
  final season = switch (month) {
    3 || 4 || 5 => localeCode == 'ko' ? '봄' : 'spring',
    6 || 7 || 8 => localeCode == 'ko' ? '여름' : 'summer',
    9 || 10 || 11 => localeCode == 'ko' ? '가을' : 'autumn',
    _ => localeCode == 'ko' ? '겨울' : 'winter',
  };
  return [
    '${kTimePrefix}year:${at.year}',
    '${kTimePrefix}season:$season',
    '${kTimePrefix}month:${at.month}',
  ];
}

int _inferImportance(Memory memory) {
  var score = 2;
  final text = '${memory.content} ${memory.summary}';
  for (final entry in kLifeEventKeywords.entries) {
    if (text.contains(entry.key)) {
      score = score < entry.value ? entry.value : score;
    }
  }
  if (emotionTagsForMemory(memory).isNotEmpty) score += 1;
  if (extractMemoryEntities(memory).people.length >= 2) score += 1;
  if (memory.type == 'image') score += 1;
  if (text.length > 120) score += 1;
  return score.clamp(1, 5);
}

/// 본문·엔티티 추출 결과로 사용자 노출 엔티티를 다시 만듭니다 (편집 후 갱신용).
List<String> rebuildUserVisibleEntitiesFromContent(
  Memory memory, {
  String localeCode = 'ko',
  GraphMemoryFragment? aiFragment,
}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode, aiFragment: aiFragment);
  final labels = <String>[
    ...bundle.people.map((p) => canonicalEntityLabel(p, localeCode: localeCode)),
    ...bundle.places,
    ...bundle.organizations,
    ...bundle.activities,
  ];
  final cleaned = labels
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && shouldShowGraphSatelliteLabel(e))
      .toList();
  return canonicalizeEntityList(cleaned, localeCode: localeCode);
}

/// 저장 직전 — 관계·이벤트·시간·중요도·엔티티 통합 (Phase E).
Memory enrichMemoryGraphSemantics(Memory memory, {String localeCode = 'ko'}) {
  final withoutInternal = memory.entities
      .where((e) =>
          !e.startsWith('tag:') &&
          !e.startsWith(kRelPrefix) &&
          !e.startsWith(kEventPrefix) &&
          !e.startsWith(kTimePrefix) &&
          !e.startsWith(kImportancePrefix))
      .toList();
  var enriched = enrichMemoryWithThemeTags(
    memory.copyWith(entities: withoutInternal),
    localeCode: localeCode,
  );

  final bundle = extractMemoryEntities(enriched, localeCode: localeCode);
  final extras = <String>[];

  final dedupedVisible = rebuildUserVisibleEntitiesFromContent(enriched, localeCode: localeCode);

  for (final rel in extractRelationsFromMemory(enriched, localeCode: localeCode)) {
    final tag = rel.toEntityTag();
    if (!enriched.entities.contains(tag)) extras.add(tag);
  }

  final eventTitle = bundle.eventTitle.trim();
  if (eventTitle.isNotEmpty && bundle.hasEventHub) {
    final hub = MemoryEventHub(
      id: eventSlugFromTitle(eventTitle),
      title: normalizeEventTitle(eventTitle),
    );
    extras.add(hub.toEntityTag());
  }

  for (final facet in _timeFacetTags(enriched.createdAt, localeCode: localeCode)) {
    extras.add(facet);
  }

  final importance = _inferImportance(enriched);
  extras.add('$kImportancePrefix$importance');

  final tags = [
    ...dedupedVisible,
    ...enriched.entities.where((e) => e.startsWith('tag:')),
    ...extras,
  ];

  final seen = <String>{};
  final merged = <String>[];
  for (final t in tags) {
    if (seen.add(t)) merged.add(t);
  }

  return enriched.copyWith(entities: merged);
}

bool memoryHasRelation(Memory memory, String predicate, String object, {String? subject}) {
  final obj = canonicalEntityLabel(object);
  for (final rel in relationsForMemory(memory)) {
    if (rel.predicate != predicate) continue;
    if (canonicalEntityLabel(rel.object) != obj) continue;
    if (subject != null && canonicalEntityLabel(rel.subject) != canonicalEntityLabel(subject)) continue;
    return true;
  }
  return false;
}

String importanceStars(int level) => '★' * level.clamp(1, 5);
