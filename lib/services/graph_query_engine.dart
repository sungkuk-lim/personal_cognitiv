import 'package:intl/intl.dart';

import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import '../utils/korean_person_names.dart';
import '../utils/memory_entity_extract.dart';
import '../utils/memory_keyword_ui.dart';
import '../utils/memory_query.dart';

/// 사전 구축된 관계망(엔티티·조각)으로 즉시 답하는 검색 — AI 호출 없음.
class GraphQueryAnswer {
  const GraphQueryAnswer({
    required this.text,
    this.relatedMemories = const [],
    this.skipAiSummary = true,
  });

  final String text;
  final List<Memory> relatedMemories;
  final bool skipAiSummary;
}

GraphQueryAnswer? tryAnswerFromGraphDb({
  required String query,
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
  required String localeCode,
  MemoryQuery? structuredQuery,
  bool Function(String memoryId)? hasPhotoFor,
  bool Function(String memoryId)? hasVideoFor,
}) {
  final q = query.trim();
  if (q.isEmpty || memories.isEmpty) return null;

  final isKo = localeCode == 'ko';

  if (structuredQuery != null && structuredQuery.isComposite) {
    final filtered = filterMemoriesByQuery(
      memories,
      structuredQuery,
      localeCode: localeCode,
      hasPhotoFor: hasPhotoFor,
      hasVideoFor: hasVideoFor,
    );
    if (filtered.isNotEmpty) {
      final summary = describeMemoryQuery(structuredQuery, localeCode: localeCode);
      final text = isKo
          ? '$summary — ${filtered.length}건'
          : '$summary — ${filtered.length} memories';
      return GraphQueryAnswer(text: text, relatedMemories: filtered.take(8).toList());
    }
  }

  final range = _parseDateRange(q, isKo);
  final scoped = _filterByRange(memories, range);

  final placeAnswer = _tryTopPlaceQuery(q, scoped, fragments, isKo);
  if (placeAnswer != null) return placeAnswer;

  final personAnswer = _tryTopPersonQuery(q, scoped, fragments, isKo);
  if (personAnswer != null) return personAnswer;

  final repeatAnswer = _tryRepeatedPlaceInsight(q, scoped, fragments, isKo);
  if (repeatAnswer != null) return repeatAnswer;

  final countAnswer = _tryMemoryCountQuery(q, scoped, isKo);
  if (countAnswer != null) return countAnswer;

  final togetherAnswer = _tryTogetherQuery(q, memories, fragments, isKo);
  if (togetherAnswer != null) return togetherAnswer;

  final topicFreqAnswer = _tryTopicFrequencyQuery(q, scoped, isKo);
  if (topicFreqAnswer != null) return topicFreqAnswer;

  final categoryAnswer = _tryCategoryCountQuery(q, scoped, isKo);
  if (categoryAnswer != null) return categoryAnswer;

  return null;
}

({DateTime? start, DateTime? end}) _parseDateRange(String q, bool isKo) {
  final now = DateTime.now();
  if (q.contains(isKo ? '작년' : 'last year')) {
    final y = now.year - 1;
    return (start: DateTime(y), end: DateTime(y, 12, 31, 23, 59, 59));
  }
  if (RegExp(isKo ? r'최근\s*(\d+)\s*일' : r'last\s*(\d+)\s*days?', caseSensitive: false).hasMatch(q)) {
    final m = RegExp(isKo ? r'최근\s*(\d+)\s*일' : r'last\s*(\d+)\s*days?', caseSensitive: false).firstMatch(q);
    final days = int.tryParse(m?.group(1) ?? '') ?? 30;
    return (start: now.subtract(Duration(days: days)), end: now);
  }
  if (q.contains(isKo ? '최근' : 'recent') || q.contains(isKo ? '이번 달' : 'this month')) {
    return (start: DateTime(now.year, now.month), end: now);
  }
  if (q.contains(isKo ? '올해' : 'this year')) {
    return (start: DateTime(now.year), end: now);
  }
  return (start: null, end: null);
}

List<Memory> _filterByRange(List<Memory> memories, ({DateTime? start, DateTime? end}) range) {
  if (range.start == null) return memories;
  return memories.where((m) {
    final t = m.createdAt;
    if (range.start != null && t.isBefore(range.start!)) return false;
    if (range.end != null && t.isAfter(range.end!)) return false;
    return true;
  }).toList();
}

Set<String> _personFilterFromQuery(String q, List<Memory> memories) {
  final hits = <String>{};
  for (final memory in memories) {
    for (final entity in userVisibleEntityLabels(memory)) {
      if (entity.length < 2) continue;
      if (q.contains(entity)) hits.add(entity);
    }
    final bundle = extractMemoryEntities(memory);
    for (final p in bundle.people) {
      if (p.length >= 2 && q.contains(p)) hits.add(p);
    }
  }
  return hits;
}

Map<String, int> _placeCounts(
  List<Memory> memories,
  Map<String, GraphMemoryFragment> fragments, {
  Set<String>? personFilter,
}) {
  final counts = <String, int>{};
  void addPlace(String label) {
    final v = label.trim();
    if (v.isEmpty || v.length < 2) return;
    counts[v] = (counts[v] ?? 0) + 1;
  }

  for (final memory in memories) {
    if (personFilter != null && personFilter.isNotEmpty) {
      final matchesPerson = personFilter.any((p) => memoryMatchesKeyword(memory, p));
      if (!matchesPerson) continue;
    }

    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        if (s.kind == 'place') addPlace(s.label);
      }
    }
    final bundle = extractMemoryEntities(memory);
    for (final place in bundle.places) {
      addPlace(place);
    }
    for (final entity in userVisibleEntityLabels(memory)) {
      if (looksLikeKoreanPlaceName(entity) || RegExp(r'(?:식당|카페|병원|공원|해변|역)$').hasMatch(entity)) {
        addPlace(entity);
      }
    }
  }
  return counts;
}

GraphQueryAnswer? _tryTopPlaceQuery(
  String q,
  List<Memory> memories,
  Map<String, GraphMemoryFragment> fragments,
  bool isKo,
) {
  final wantsPlace = q.contains(isKo ? '장소' : 'place') ||
      q.contains(isKo ? '어디' : 'where') ||
      q.contains(isKo ? '방문' : 'visit');
  if (!wantsPlace) return null;

  final personFilter = _personFilterFromQuery(q, memories);
  final counts = _placeCounts(memories, fragments, personFilter: personFilter.isEmpty ? null : personFilter);
  if (counts.isEmpty) return null;

  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  final related = memories.where((m) {
    if (personFilter.isNotEmpty && !personFilter.any((p) => memoryMatchesKeyword(m, p))) return false;
    return memoryMatchesKeyword(m, top.key);
  }).take(6).toList();

  final personPart = personFilter.isEmpty
      ? ''
      : isKo
          ? '${personFilter.join('·')}와(과) '
          : 'with ${personFilter.join(', ')} ';
  final text = isKo
      ? '${personPart}가장 많이 기록된 장소는 「${top.key}」입니다 (${top.value}회).'
      : 'The place you recorded most often ${personPart}is "${top.key}" (${top.value} times).';
  return GraphQueryAnswer(text: text, relatedMemories: related);
}

GraphQueryAnswer? _tryTopPersonQuery(
  String q,
  List<Memory> memories,
  Map<String, GraphMemoryFragment> fragments,
  bool isKo,
) {
  final wantsPerson = q.contains(isKo ? '인물' : 'people') ||
      q.contains(isKo ? '사람' : 'person') ||
      q.contains(isKo ? '가장 많이' : 'most often');
  if (!wantsPerson) return null;

  final counts = <String, int>{};
  void addPerson(String label) {
    final v = label.trim();
    if (v.isEmpty || v.length < 2) return;
    counts[v] = (counts[v] ?? 0) + 1;
  }

  for (final memory in memories) {
    final fragment = fragments[memory.id];
    if (fragment != null) {
      for (final s in fragment.satellites) {
        if (s.kind == 'person') addPerson(s.label);
      }
    }
    final bundle = extractMemoryEntities(memory);
    for (final p in bundle.people) {
      addPerson(p);
    }
    for (final e in userVisibleEntityLabels(memory)) {
      if (isLikelyKoreanPersonName(e)) addPerson(e);
    }
  }

  if (counts.isEmpty) return null;
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  final related = memories.where((m) => memoryMatchesKeyword(m, top.key)).take(6).toList();
  final text = isKo
      ? '관계망에서 가장 자주 등장하는 인물은 「${top.key}」입니다 (${top.value}건).'
      : 'The person who appears most in your graph is "${top.key}" (${top.value} memories).';
  return GraphQueryAnswer(text: text, relatedMemories: related);
}

GraphQueryAnswer? _tryRepeatedPlaceInsight(
  String q,
  List<Memory> memories,
  Map<String, GraphMemoryFragment> fragments,
  bool isKo,
) {
  if (!q.contains(isKo ? '반복' : 'repeat') && !q.contains(isKo ? '몇 회' : 'how many')) {
    return null;
  }
  final counts = _placeCounts(memories, fragments);
  final repeated = counts.entries.where((e) => e.value >= 3).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (repeated.isEmpty) return null;

  final top = repeated.first;
  final text = isKo
      ? '「${top.key}」 방문이 ${top.value}회 반복되었습니다.'
      : 'You visited "${top.key}" ${top.value} times.';
  final related = memories.where((m) => memoryMatchesKeyword(m, top.key)).take(6).toList();
  return GraphQueryAnswer(text: text, relatedMemories: related);
}

GraphQueryAnswer? _tryMemoryCountQuery(String q, List<Memory> memories, bool isKo) {
  final wantsCount = q.contains(isKo ? '몇' : 'how many') ||
      q.contains(isKo ? '얼마나' : 'how much') ||
      q.contains(isKo ? '건' : 'count');
  if (!wantsCount) return null;

  final personFilter = _personFilterFromQuery(q, memories);
  final scoped = personFilter.isEmpty
      ? memories
      : memories.where((m) => personFilter.any((p) => memoryMatchesKeyword(m, p))).toList();
  if (scoped.isEmpty) return null;

  final text = personFilter.isEmpty
      ? (isKo ? '해당 기간 기억은 총 ${scoped.length}건입니다.' : 'You have ${scoped.length} memories in this range.')
      : (isKo
          ? '${personFilter.join('·')} 관련 기억은 ${scoped.length}건입니다.'
          : '${scoped.length} memories related to ${personFilter.join(', ')}.');
  return GraphQueryAnswer(text: text, relatedMemories: scoped.take(8).toList());
}

GraphQueryAnswer? _tryTogetherQuery(
  String q,
  List<Memory> memories,
  Map<String, GraphMemoryFragment> fragments,
  bool isKo,
) {
  if (!q.contains(isKo ? '함께' : 'together') && !q.contains(isKo ? '같이' : 'with')) {
    return null;
  }
  final people = <String>[];
  for (final memory in memories) {
    for (final entity in userVisibleEntityLabels(memory)) {
      if (entity.length >= 2 && q.contains(entity) && isLikelyKoreanPersonName(entity)) {
        people.add(entity);
      }
    }
  }
  final unique = people.toSet().toList();
  if (unique.length < 2) return null;

  final related = memories.where((m) => unique.every((p) => memoryMatchesKeyword(m, p))).take(8).toList();
  if (related.isEmpty) return null;

  final text = isKo
      ? '${unique.join('·')}이(가) 함께 나오는 기억은 ${related.length}건입니다.'
      : '${related.length} memories where ${unique.join(' & ')} appear together.';
  return GraphQueryAnswer(text: text, relatedMemories: related);
}

GraphQueryAnswer? _tryTopicFrequencyQuery(String q, List<Memory> memories, bool isKo) {
  final topics = ['Flutter', 'flutter', '공부', '운동', '병원', '회사', '여행'];
  String? hit;
  for (final topic in topics) {
    if (q.contains(topic)) {
      hit = topic;
      break;
    }
  }
  if (hit == null) return null;
  if (!q.contains(isKo ? '몇' : 'how') && !q.contains(isKo ? '얼마나' : 'often') && !q.contains(isKo ? '자주' : 'frequent')) {
    return null;
  }

  final related = memories.where((m) => memoryMatchesKeyword(m, hit!)).toList();
  if (related.isEmpty) return null;
  final text = isKo
      ? '「$hit」 관련 기록은 ${related.length}건입니다.'
      : 'You have ${related.length} memories about "$hit".';
  return GraphQueryAnswer(text: text, relatedMemories: related.take(8).toList());
}

GraphQueryAnswer? _tryCategoryCountQuery(String q, List<Memory> memories, bool isKo) {
  final mapping = isKo
      ? {
          '가족': '가족',
          '연인': '연인',
          '친구': '친구',
          '회사': '회사',
          '공부': '공부',
          '여행': '여행',
        }
      : {
          'family': 'Family',
          'partner': 'Partner',
          'friend': 'Friends',
          'work': 'Work',
          'study': 'Study',
          'travel': 'Travel',
        };

  String? subHit;
  for (final entry in mapping.entries) {
    if (q.toLowerCase().contains(entry.key.toLowerCase())) {
      subHit = entry.value;
      break;
    }
  }
  if (subHit == null) return null;
  final tag = subHit;

  final related = memories.where((m) => m.subCategory == tag || m.subCategory.contains(tag)).toList();
  if (related.isEmpty) return null;
  final text = isKo
      ? '「$tag」 맥락 기록은 ${related.length}건입니다.'
      : 'You have ${related.length} memories tagged "$tag".';
  return GraphQueryAnswer(text: text, relatedMemories: related.take(8).toList());
}

String buildCompactSearchContext(
  List<Memory> matches,
  Map<String, GraphMemoryFragment> fragments, {
  int limit = 8,
}) {
  final buf = StringBuffer();
  for (final memory in matches.take(limit)) {
    final fragment = fragments[memory.id];
    final title = fragment != null && fragment.isUsable ? fragment.meaningTitle : memory.summary.trim();
    final date = DateFormat('yyyy-MM-dd').format(memory.createdAt);
    final entities = userVisibleEntityLabels(memory).take(6).join(', ');
    final places = fragment?.satellites.where((s) => s.kind == 'place').map((s) => s.label).take(2).join(', ') ?? '';
    final people = fragment?.satellites.where((s) => s.kind == 'person').map((s) => s.label).take(4).join(', ') ?? '';
    buf.writeln('[$date] ${title.isNotEmpty ? title : memory.id} | people:$people | places:$places | tags:$entities');
  }
  return buf.toString().trim();
}
