import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'entity_canonical.dart';
import 'graph_entity_quality.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';
import 'memory_participation_extract.dart';
import 'memory_entity_edit.dart';
import 'memory_quantity_validate.dart';
import 'memory_semantic_extract.dart';
import 'memory_semantic_flow.dart';
import 'memory_theme_tags.dart';
import 'organization_hierarchy.dart';

/// 관계: rel:{predicate}:{object} 또는 rel:{subject}:{predicate}:{object}
const String kRelPrefix = 'rel:';
const String kEventPrefix = 'event:';
const String kTimePrefix = 'time:';
const String kImportancePrefix = 'importance:';

const kRelationPredicates = {
  '동행': ['함께', '같이', '동행', '와', '과'],
  '만남': ['만나', '만난', '만났', '만났다'],
  '방문': ['방문', '갔', '다녀', '여행', '도착'],
  '회의': ['회의', '미팅', '논의'],
  '발표': ['발표', '프레젠', '세미나'],
  '식사': ['식사', '먹', '저녁', '점심', '아침', '식당'],
  '촬영': ['사진', '촬영', '찍', '셀카'],
  '대화': ['이야기', '대화', '얘기', '수다'],
  '운전': ['운전', '드라이브', '차로'],
  '축하': ['축하', '생일', '기념'],
  '도움': ['도움', '도와', '부탁'],
  '공부': ['공부', '학습', '수업'],
  '운동': ['운동', '달리', '헬스', '수영'],
  '개발': ['개발', '구현', '코딩', '프로그래밍'],
  '출시': ['출시', '런칭', '공개', '오픈'],
  '투자': ['투자', '펀딩', '지원'],
  '설립': ['설립', '창업', '시작'],
  '인수': ['인수', '매수'],
  '구매': ['구매', '구입', '샀', '주문'],
  '응시': ['시험', '응시', '친대', '봤'],
  '응원': ['응원', '좋겠', '바라', '힘내', '잘 쳤'],
  '좋아함': ['좋아하', '좋아해', '즐겨', '선호'],
  '싫어함': ['싫어하', '싫어해', '꺼려'],
  '외진': ['외진', '내원', '외래'],
  '진료': ['진료', '진료과', '과로', '과에'],
  '소속': ['소속', '병원에', '병원에는'],
  '총인원': ['총', '명이', '명이 왔', '명이 나왔'],
  '보고': ['보고', '현황', '기록으로'],
  '출발': ['에서', '출발', '보냈'],
  '인솔': ['인솔', '동행', '안내', '호송'],
  '진료과': ['진료과', '과에', '과의'],
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

/// 저장된 rel: 태그 + 본문 추출 관계를 합칩니다 (관계망·AI 훅용).
List<MemoryRelation> effectiveRelationsForMemory(Memory memory, {String localeCode = 'ko'}) {
  if (memoryHasManualEntityEdit(memory)) {
    return relationsForMemory(memory);
  }
  return _dedupeRelations([
    ...relationsForMemory(memory),
    ...extractRelationsFromMemory(memory, localeCode: localeCode),
  ]);
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
    if (isNegatedRelationContext(text, '함께') || isNegatedRelationContext(text, p)) continue;
    final escaped = RegExp.escape(p);
    if (text.contains('함께') ||
        text.contains('같이') ||
        RegExp('(?:와|과|랑|이랑)\\s*$escaped').hasMatch(text) ||
        RegExp('$escaped(?:와|과|랑|이랑)').hasMatch(text)) {
      relations.add(MemoryRelation(predicate: '동행', object: p));
    }
  }

  for (final place in bundle.places) {
    final pl = canonicalEntityLabel(place);
    if (pl.isEmpty) continue;
    if (isNegatedRelationContext(text, '방문') || isNegatedRelationContext(text, pl)) continue;
    relations.add(MemoryRelation(predicate: '방문', object: pl));
  }

  for (final food in foodTagsForMemory(memory)) {
    if (isNegatedRelationContext(text, food) || isNegatedRelationContext(text, '먹')) continue;
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
      if (entry.key == '동행' ||
          entry.key == '방문' ||
          entry.key == '식사' ||
          entry.key == '응시' ||
          entry.key == '응원' ||
          entry.key == '좋아함' ||
          entry.key == '싫어함') {
        continue;
      }
      if (entry.value.any((w) => activity.contains(w) || text.contains(w))) {
        if (entry.value.any((w) => isNegatedRelationContext(text, w))) continue;
        relations.add(MemoryRelation(predicate: entry.key, object: activity));
      }
    }
  }

  if ((text.contains('좋아하') || text.contains('좋아해') || text.contains('즐겨')) &&
      !isNegatedRelationContext(text, '좋아하')) {
    var interestLabels = <String>{
      ...interestTagsForMemory(memory, localeCode: localeCode),
      ...extractSemanticFromText(memory.content).interests,
    };
    if (interestLabels.isEmpty && text.contains('AI')) {
      interestLabels.add('AI');
    }
    for (final tag in interestLabels) {
      final label = canonicalEntityLabel(tag);
      if (label.isNotEmpty) {
        relations.add(MemoryRelation(predicate: '좋아함', object: label));
      }
    }
  }
  if (RegExp(r'싫어하|싫어해|꺼려').hasMatch(text) && !isNegatedRelationContext(text, '싫어하')) {
    for (final tag in interestTagsForMemory(memory, localeCode: localeCode)) {
      final label = canonicalEntityLabel(tag);
      if (label.isNotEmpty) {
        relations.add(MemoryRelation(predicate: '싫어함', object: label));
      }
    }
  }

  for (final match in RegExp(r'([가-힣]{2,4})이\s+([가-힣]{2,4})를?\s+(?:고용|초대|데려)').allMatches(text)) {
    final subject = normalizeKoreanPersonName(match.group(1)!);
    final object = normalizeKoreanPersonName(match.group(2)!);
    if (subject.isNotEmpty && object.isNotEmpty) {
      relations.add(MemoryRelation(subject: subject, predicate: '고용', object: object));
    }
  }

  _appendFamilyExamRelations(relations, memory, bundle, text, localeCode);
  _appendSemanticFlowRelations(relations, text, localeCode);

  return _dedupeRelations(relations);
}

void _appendSemanticFlowRelations(
  List<MemoryRelation> relations,
  String text,
  String localeCode,
) {
  final frame = parseMemorySemanticFlow(text, localeCode: localeCode);
  if (frame.structuredRelations.isEmpty) return;
  for (final rel in frame.structuredRelations) {
    relations.add(rel);
  }
}

void _appendFamilyExamRelations(
  List<MemoryRelation> relations,
  Memory memory,
  MemoryEntityBundle bundle,
  String text,
  String localeCode,
) {
  if (!text.contains('시험')) return;

  final examLabel = bundle.events.isNotEmpty
      ? bundle.events.first
      : (bundle.eventTitle.isNotEmpty ? bundle.eventTitle : '시험');

  for (final person in bundle.people) {
    if (person == selfPersonGraphLabel(localeCode)) continue;
    final escaped = RegExp.escape(person);
    if (!RegExp('$escaped(?:이|가|은|는|과|와|랑|이랑|을|를|의|님|씨|도|만|하고)?(?=[\\s,.]|\$)')
        .hasMatch(text)) {
      continue;
    }
    relations.add(MemoryRelation(subject: person, predicate: '응시', object: examLabel));
  }

  final self = selfPersonGraphLabel(localeCode);
  final wishesWell = RegExp(r'잘\s*쳤|좋겠|바라|응원|힘내|기도').hasMatch(text);
  if (!wishesWell) return;

  for (final person in bundle.people) {
    if (person == self) continue;
    if (isFamilyRelationTerm(person) || isLikelyKoreanPersonName(person)) {
      relations.add(MemoryRelation(subject: self, predicate: '응원', object: person));
    }
  }
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
    ...bundle.events,
    ...bundle.activities,
    ...bundle.interests,
    ...bundle.contents,
    ...bundle.food,
    ...bundle.hobbies,
    ...bundle.emotions,
  ];
  final cleaned = labels
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && shouldShowGraphSatelliteLabel(e))
      .toList();
  return canonicalizeEntityList(cleaned, localeCode: localeCode);
}

/// 저장 직전 — 관계·이벤트·시간·중요도·엔티티 통합 (Phase E).
Memory enrichMemoryGraphSemantics(Memory memory, {String localeCode = 'ko'}) {
  final manualVisible = memoryHasManualEntityEdit(memory)
      ? editableEntityLabelsForMemory(memory)
      : null;
  final withoutInternal = memory.entities
      .where((e) =>
          !e.startsWith('tag:') &&
          !e.startsWith(kRelPrefix) &&
          !e.startsWith(kEventPrefix) &&
          !e.startsWith(kTimePrefix) &&
          !e.startsWith(kImportancePrefix) &&
          !e.startsWith(kHierarchyJsonPrefix))
      .toList();
  final preservedHierarchyTags = memory.entities
      .where((e) => e.startsWith(kHierarchyJsonPrefix))
      .toList();
  var enriched = enrichMemoryWithThemeTags(
    memory.copyWith(entities: withoutInternal),
    localeCode: localeCode,
  );

  final bundle = extractMemoryEntities(enriched, localeCode: localeCode);
  final flowFrame = parseMemorySemanticFlow(
    '${enriched.content}\n${enriched.summary}',
    localeCode: localeCode,
    entityTags: preservedHierarchyTags,
  );
  final extras = <String>[];
  if (manualVisible == null) {
    extras.addAll(countTagsFromFrame(flowFrame));
  }

  final dedupedVisible = manualVisible ?? rebuildUserVisibleEntitiesFromContent(enriched, localeCode: localeCode);

  if (manualVisible == null) {
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
  }

  for (final facet in _timeFacetTags(enriched.createdAt, localeCode: localeCode)) {
    extras.add(facet);
  }

  final importance = _inferImportance(enriched);
  extras.add('$kImportancePrefix$importance');

  final tags = [
    ...dedupedVisible,
    ...enriched.entities.where((e) => e.startsWith('tag:') && e != kTagEntitiesManual),
    if (manualVisible != null) kTagEntitiesManual,
    ...preservedHierarchyTags,
    ...extras,
  ];

  final seen = <String>{};
  final merged = <String>[];
  for (final t in tags) {
    if (seen.add(t)) merged.add(t);
  }

  return enriched.copyWith(entities: merged);
}

bool memoryHasRelation(Memory memory, String predicate, String object, {String? subject, String localeCode = 'ko'}) {
  final obj = canonicalEntityLabel(object);
  for (final rel in effectiveRelationsForMemory(memory, localeCode: localeCode)) {
    if (rel.predicate != predicate) continue;
    if (canonicalEntityLabel(rel.object) != obj) continue;
    if (subject != null && canonicalEntityLabel(rel.subject) != canonicalEntityLabel(subject)) continue;
    return true;
  }
  return false;
}

String importanceStars(int level) => '★' * level.clamp(1, 5);
