import '../models/graph_ai_snapshot.dart';
import '../models/memory.dart';
import 'memory_detail_text.dart';
import 'graph_fragment_freshness.dart';
import 'graph_meaning_extract.dart';
import 'korean_person_names.dart';
import 'memory_participation_extract.dart';
import 'memory_semantic_extract.dart';
import 'ocr_utils.dart';
import 'photo_memory_format.dart';

/// 관계망 위성 — 인물·장소·조직 상한.
const int kGraphMaxPeopleSatellites = 12;
const int kGraphMaxPlaceSatellites = 3;
const int kGraphMaxOrgSatellites = 3;

/// 음식·일반명사 — 그래프 노드에서 제외.
const Set<String> kGraphFoodNoiseTokens = {
  '탕수육', '자장면', '술', '치킨', '삼겹살', '장어구이', '조개구이', '회', '밥', '음식',
  '여러가지', '이런저런', '이야기', '얘기', '대화', '메뉴',
};

const Set<String> kGraphMealCompanionTokens = {
  '식사', '저녁', '점심', '아침', '간식', '브런치', '런치',
};

bool isGraphMealCompanionToken(String token) => kGraphMealCompanionTokens.contains(token.trim());

/// 인물로 오인되는 직함·집합 명사·카테고리 키워드.
const Set<String> kBlockedPersonTokens = {
  '원직원들', '직원들', '병원직원들', '병원직원', '간호과장', '간호팀장', '간호사', '보호사',
  '참석자', '참석', '팀장', '과장', '원장', '부장', '이사', '대리', '사원',
  '여러가지', '이런저런', '모두', '전원', '직원',
  '시험', '컴퓨터', '공부', '능력', '활용', '자격', '증', '급',
};

class MemoryEntityBundle {
  const MemoryEntityBundle({
    required this.eventTitle,
    this.people = const [],
    this.organizations = const [],
    this.places = const [],
    this.activities = const [],
    this.events = const [],
    this.interests = const [],
    this.contents = const [],
    this.food = const [],
    this.hobbies = const [],
    this.emotions = const [],
  });

  final String eventTitle;
  final List<String> people;
  final List<String> organizations;
  final List<String> places;
  final List<String> activities;
  final List<String> events;
  final List<String> interests;
  final List<String> contents;
  final List<String> food;
  final List<String> hobbies;
  final List<String> emotions;

  bool get hasEventHub =>
      eventTitle.isNotEmpty && !isGenericHubTitle(eventTitle);
}

bool isBlockedPersonName(String raw) {
  final name = normalizeKoreanPersonName(raw.trim());
  if (name == '나' || name == 'Me') return false;
  if (name.isEmpty || name.length < 2) return true;
  if (kBlockedPersonTokens.contains(name)) return true;
  if (kGraphFoodNoiseTokens.contains(name)) return true;
  if (RegExp(r'(?:과장|팀장|원장|부장|이사|대리|사원)$').hasMatch(name) && name.length <= 5) {
    return true;
  }
  return false;
}

bool isGraphFoodOrNoiseToken(String token) {
  final t = token.trim();
  if (t.isEmpty) return true;
  if (t == '나' || t == 'Me') return false;
  if (t.length <= 1) return true;
  if (kGraphFoodNoiseTokens.contains(t)) return true;
  if (isGraphMealCompanionToken(t)) return true;
  if (RegExp(r'^(?:이런|저런|여러)').hasMatch(t)) return true;
  return false;
}

/// 구조화 엔티티 — 규칙 기반 (AI 조각과 병합 가능).
MemoryEntityBundle extractMemoryEntities(
  Memory memory, {
  String localeCode = 'ko',
  GraphMemoryFragment? aiFragment,
}) {
  final content = memory.content.trim();
  if (memory.type == 'graph_note') {
    final anchor = memory.summary.contains('·')
        ? memory.summary.split('·').first.trim()
        : (memory.entities.isNotEmpty ? memory.entities.first : '');
    final people = anchor.isNotEmpty && !isBlockedPersonName(anchor) ? [anchor] : <String>[];
    return MemoryEntityBundle(
      eventTitle: '',
      people: people,
      organizations: const [],
      places: const [],
      activities: const [],
      events: const [],
      interests: const [],
      contents: const [],
      food: const [],
      hobbies: const [],
      emotions: const [],
    );
  }

  final effectiveFragment = freshGraphFragmentForMemory(memory, aiFragment);

  final localPeople = extractPeopleFromMemoryText(content);
  final localPlaces = extractPlacesFromMemoryText(content);
  final localOrgs = extractOrganizationsFromText(content, localeCode: localeCode);
  final eventTitle = _resolveEventTitle(
    content: content,
    memory: memory,
    localeCode: localeCode,
    aiFragment: effectiveFragment,
  );

  var people = <String>[...localPeople];
  var places = <String>[...localPlaces];
  var orgs = <String>[...localOrgs];
  var activities = <String>[];
  var events = <String>[];
  var interests = <String>[];
  var contents = <String>[];
  var food = <String>[];
  var hobbies = <String>[];
  var emotions = <String>[];

  final semantic = extractSemanticFromText(content);
  events.addAll(semantic.events);
  interests.addAll(semantic.interests);
  contents.addAll(semantic.contents);
  food.addAll(semantic.food);
  hobbies.addAll(semantic.hobbies);
  emotions.addAll(semantic.emotions);
  activities.addAll(semantic.activities);

  if (effectiveFragment != null) {
    for (final s in effectiveFragment.satellites) {
      final label = s.label.trim();
      if (label.isEmpty || isGraphFoodOrNoiseToken(label)) continue;
      switch (s.kind) {
        case 'person':
          if (!isBlockedPersonName(label)) {
            final norm = normalizeKoreanPersonName(label);
            if (isFamilyRelationTerm(norm) || isLikelyKoreanPersonName(norm)) {
              people.add(norm);
            }
          }
        case 'place':
          if (!people.contains(label)) places.add(label);
        case 'organization':
          orgs.add(label);
        case 'activity':
          if (!isGraphFoodOrNoiseToken(label) &&
              label.length >= 2 &&
              !_isPersonPlaceCompositeActivity(label)) {
            activities.add(label);
          }
        case 'event':
          events.add(label);
        case 'content':
          contents.add(label);
        case 'interest':
          interests.add(label);
        case 'food':
          food.add(label);
        case 'hobby':
          hobbies.add(label);
        case 'emotion':
          emotions.add(label);
        case 'goal':
          if (label.length >= 2) interests.add(label);
        default:
          break;
      }
    }
  }

  people = _dedupeOrdered(people)
      .where((p) => !isKnownFoodLabel(p) && !isKnownContentLabel(p))
      .where((p) => !isGraphVenueToken(p) && !_looksLikePlaceLabel(p))
      .where((p) => !isGraphMorphologyJunkToken(p))
      .take(kGraphMaxPeopleSatellites)
      .toList();
  places = _dedupeOrdered(places).take(kGraphMaxPlaceSatellites).toList();
  orgs = _dedupeOrdered(orgs).take(kGraphMaxOrgSatellites).toList();
  activities.addAll(_extractActivitiesFromContent(content, people, memory.entities));
  activities = _dedupeOrdered(activities)
      .where((a) => !_isPersonPlaceCompositeActivity(a))
      .where((a) => !isGraphFoodOrNoiseToken(a))
      .where((a) {
        if (events.isEmpty) return true;
        final primary = events.first;
        if (primary.contains(a) || a.contains('시험') && primary.contains('시험')) return false;
        return true;
      })
      .take(2)
      .toList();

  for (final e in sanitizeEntities(memory.entities)) {
    final trimmed = e.trim();
    if (!entityLabelReferencedInMemory(trimmed, memory)) continue;
    final norm = normalizeKoreanPersonName(stripTrailingKoreanParticles(trimmed));
    if (isKnownFoodLabel(trimmed) || isKnownContentLabel(trimmed) ||
        isKnownFoodLabel(norm) || isKnownContentLabel(norm)) {
      continue;
    }
    if (isGraphVenueToken(trimmed) || isGraphVenueToken(norm) || _looksLikePlaceLabel(trimmed) || looksLikeKoreanPlaceName(trimmed)) {
      places.add(trimmed);
      continue;
    }
    if ((isFamilyRelationTerm(norm) || isLikelyKoreanPersonName(norm)) && !isBlockedPersonName(norm)) {
      people.add(norm);
    }
  }

  people = _dedupeOrdered(people)
      .where((p) => !isKnownFoodLabel(p) && !isKnownContentLabel(p))
      .where((p) => !isGraphVenueToken(p) && !_looksLikePlaceLabel(p))
      .where((p) => !isGraphMorphologyJunkToken(p))
      .take(kGraphMaxPeopleSatellites)
      .toList();
  places = _dedupeOrdered(places).take(kGraphMaxPlaceSatellites).toList();

  if (memory.type != 'graph_note') {
    final self = selfPersonGraphLabel(localeCode);
    if (!people.contains(self)) {
      people = [self, ...people];
    }
  }

  return MemoryEntityBundle(
    eventTitle: eventTitle,
    people: people,
    organizations: orgs,
    places: places,
    activities: activities,
    events: _dedupeOrdered(events).take(3).toList(),
    interests: _dedupeOrdered(interests).take(3).toList(),
    contents: _dedupeOrdered(contents).take(3).toList(),
    food: _dedupeOrdered(food).take(2).toList(),
    hobbies: _dedupeOrdered(hobbies).take(2).toList(),
    emotions: _dedupeOrdered(emotions).take(2).toList(),
  );
}

const int kHubTitleMaxLen = 48;

bool memoryTextHasMultipleClauses(String text) {
  final t = text.trim();
  return RegExp(r'[,，]|(?:뒤|후)\s|(?:봤고|갔고|했고|먹고|마시고|즐기|가기로)').hasMatch(t);
}

bool isGenericHubTitle(String text, {String localeCode = 'ko'}) {
  final v = text.trim();
  if (v.isEmpty) return true;
  if (localeCode == 'ko') {
    return v == '기억에 남는 순간.' ||
        v == '기억에 남는 하루의 한 조각.' ||
        v == '기억' ||
        v.startsWith('기억에 남는');
  }
  return v == 'A moment worth remembering.' || v == 'A slice of life worth keeping.';
}

/// 본문에 「삶」이 없는데 summary/허브에 「삶아 먹음」만 붙은 옛 규칙 오류.
bool isFalseBoiledMealHubTitle(String title, String content) {
  if (!RegExp(r'삶아\s*먹음').hasMatch(title.trim())) return false;
  return !content.contains('삶');
}

/// 저장 summary·그래프 공통 — 본문만으로 허브 제목 (마침표 제외).
String inferHubTitleFromContent(String content, {String localeCode = 'ko'}) {
  final title = _resolveEventTitle(
    content: content,
    memory: Memory(
      id: '',
      content: content.trim(),
      summary: '',
      entities: const [],
      createdAt: DateTime(1970),
    ),
    localeCode: localeCode,
  );
  return title.replaceAll(RegExp(r'[.!?…]+$'), '').trim();
}

String composeMemoryHubTitle(String text, {required String localeCode}) {
  if (localeCode != 'ko') return '';
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length < 6) return '';

  final semantic = extractSemanticFromText(t);
  final places = extractPlacesFromMemoryText(t);
  final segments = <String>[];
  final seen = <String>{};

  void add(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty || v.length > 18) return;
    if (!seen.add(v)) return;
    segments.add(v);
  }

  if (places.isNotEmpty) {
    for (final p in places) {
      if (!isPersonPlaceCompositeActivity(p)) add(p);
    }
  }

  for (final f in semantic.food) {
    add(f);
  }

  final book = RegExp(r'『([^』]{1,18})』').firstMatch(t);
  if (book != null) add(book.group(1));

  for (final c in semantic.contents) {
    add(c);
  }
  for (final e in semantic.events) {
    add(e);
  }

  final festival = RegExp(r'([가-힣]{2,12}영화제)').firstMatch(t);
  if (festival != null) add(festival.group(1));

  const activityHints = [
    '보드게임', '산책', '공연', '독서 모임', '커피', '영화', '여행', '회식', '시험', '창업', '스타트업',
  ];
  for (final hint in activityHints) {
    if (t.contains(hint)) add(hint);
  }

  for (final h in semantic.hobbies) {
    add(h);
  }
  for (final a in semantic.activities) {
    add(a);
  }

  if (places.length > 1) {
    for (final p in places.skip(1)) {
      if (!isPersonPlaceCompositeActivity(p)) add(p);
    }
  }

  if (segments.length < 2) {
    final org = RegExp(
      r'([가-힣A-Za-z0-9]{2,12}(?:전자|그룹|은행|회사|병원|학교|대학교|네이버|카카오|쿠팡))',
    ).firstMatch(t);
    if (org != null) add(org.group(1));
  }

  if (segments.isEmpty) return '';

  if (segments.length == 1 && places.any((p) => p == segments.first)) {
    return '';
  }

  segments.sort((a, b) {
    final ai = t.indexOf(a);
    final bi = t.indexOf(b);
    return (ai < 0 ? 9999 : ai).compareTo(bi < 0 ? 9999 : bi);
  });

  return _polishHubTitle(segments.take(5).join('·'));
}

String finalizeHubTitle(String raw) => _polishHubTitle(raw);

String hubTitleFromContentLine(String content, {required String localeCode}) {
  final line = extractBestMeaningLineForGraph(content, localeCode: localeCode);
  if (line.isEmpty || isGenericHubTitle(line, localeCode: localeCode)) return '';
  if (isGraphMetaContent(line)) return '';
  return _polishHubTitle(line.replaceAll(RegExp(r'[.!?…]+$'), ''));
}

String _polishHubTitle(String raw) {
  var value = raw.trim().replaceAll(RegExp(r'[.!?…]+$'), '');
  if (value.isEmpty) return '';
  if (value.length > kHubTitleMaxLen) {
    final cut = value.lastIndexOf('·', kHubTitleMaxLen);
    if (cut > 10) {
      value = '${value.substring(0, cut)}…';
    } else {
      value = '${value.substring(0, kHubTitleMaxLen - 1)}…';
    }
  }
  return '$value.';
}

bool isMeaningfulHubTitle(String title, {String localeCode = 'ko'}) {
  final v = title.trim();
  if (v.isEmpty || isGraphMetaContent(v) || isGenericHubTitle(v, localeCode: localeCode)) {
    return false;
  }
  return v.length >= 4;
}

String _resolveEventTitle({
  required String content,
  required Memory memory,
  required String localeCode,
  GraphMemoryFragment? aiFragment,
}) {
  if (memoryTextHasMultipleClauses(content)) {
    final composed = composeMemoryHubTitle(content, localeCode: localeCode);
    if (isMeaningfulHubTitle(composed, localeCode: localeCode)) return composed;
  }

  final fromEvent = extractEventTitleFromText(content, localeCode: localeCode);
  if (fromEvent.isNotEmpty && isMeaningfulHubTitle(fromEvent, localeCode: localeCode)) {
    return fromEvent;
  }

  final composed = composeMemoryHubTitle(content, localeCode: localeCode);
  if (isMeaningfulHubTitle(composed, localeCode: localeCode)) return composed;

  final fromContent = hubTitleFromContentLine(content, localeCode: localeCode);
  if (isMeaningfulHubTitle(fromContent, localeCode: localeCode)) return fromContent;

  final summary = memory.summary.trim();
  if (summary.isNotEmpty &&
      !isPhotoStyleSummary(summary) &&
      !isFalseBoiledMealHubTitle(summary, content) &&
      isMeaningfulHubTitle(summary, localeCode: localeCode)) {
    final fromSummary = hubTitleFromContentLine(summary, localeCode: localeCode);
    if (fromSummary.isNotEmpty) return fromSummary;
    return finalizeHubTitle(summary);
  }

  final aiTitle = aiFragment?.meaningTitle.trim() ?? '';
  if (aiTitle.isNotEmpty && isMeaningfulHubTitle(aiTitle, localeCode: localeCode)) {
    return aiTitle;
  }

  return localeCode == 'ko' ? '기억에 남는 순간.' : 'A moment worth remembering.';
}

/// 사건 중심 허브 제목 (회식·회의·여행 등).
String extractEventTitleFromText(String text, {String localeCode = 'ko'}) {
  final t = text.trim();
  if (t.isEmpty) return '';

  if (localeCode == 'ko') {
    if (!memoryTextHasMultipleClauses(t)) {
      final boiled = RegExp(r'([가-힣]{2,8})(?:을|를)\s*삶(?:아|아서)\s*먹').firstMatch(t);
      if (boiled != null) {
        final item = boiled.group(1)!.trim();
        if (isKnownFoodLabel(item) ||
            (!isFamilyRelationTerm(item) &&
                !isCompoundParentTerm(item) &&
                !isLikelyKoreanPersonName(item))) {
          return '$item 삶아 먹음';
        }
      }
      final meal = RegExp(r'([가-힣]{2,8})(?:을|를)\s*먹').firstMatch(t);
      if (meal != null) {
        final item = meal.group(1)!.trim();
        if (isKnownFoodLabel(item) ||
            (!isFamilyRelationTerm(item) &&
                !isCompoundParentTerm(item) &&
                !isLikelyKoreanPersonName(item))) {
          return '$item 먹음';
        }
      }
    }
    if (t.contains('회식')) {
      if (t.contains('병원') || t.contains('직원')) return '병원 직원 회식';
      return '회식';
    }
    if (t.contains('워크숍')) return '워크숍';
    if (t.contains('교육') && (t.contains('받') || t.contains('참'))) return '교육';
    if (t.contains('회의')) return '회의';
    if (t.contains('여행')) return '여행';
    if (t.contains('생일')) return '생일';
    if (t.contains('결혼식')) return '결혼식';
    final workplace = RegExp(
      r'([가-힣A-Za-z0-9]{2,12}(?:전자|그룹|은행|회사|병원|학교|대학교))(?:에서|에)\s+',
    ).firstMatch(t);
    if (workplace != null &&
        RegExp(r'(?:일한다|근무|다닌|출근|취직|입사|재직)').hasMatch(t)) {
      return '${workplace.group(1)} 근무';
    }
    final body = _textAfterSubject(t).replaceFirst(RegExp(r'^(?:오늘|내일|어제)\s+'), '');
    final exam = RegExp(
      r'([가-힣A-Za-z0-9]+(?:\s+[가-힣A-Za-z0-9]+){0,5}\s*시험)',
    ).firstMatch(body);
    if (exam != null) return exam.group(1)!.trim();
    if (t.contains('시험')) return '시험';
    final outing = RegExp(r'([가-힣]{2,8}(?:천|산|공원|해변|계곡|바다|강))에\s+(?:놀러|갔)').firstMatch(t);
    if (outing != null) return '${outing.group(1)} 나들이';
    if (t.contains('놀러갔') || t.contains('놀러 갔')) {
      final place = extractPlaceHintFromOcr(t);
      if (place != null && place.isNotEmpty) return '$place 나들이';
      return '가족 나들이';
    }
  } else {
    if (RegExp(r'dinner|회식', caseSensitive: false).hasMatch(t)) {
      return t.contains('hospital') || t.contains('staff') ? 'Hospital staff dinner' : 'Team dinner';
    }
    if (t.contains('meeting')) return 'Meeting';
    if (t.contains('trip') || t.contains('travel')) return 'Trip';
  }

  final eventLine = RegExp(r'[^.!\n]{4,48}(?:회식|회의|여행|교육|워크숍)[^.!\n]{0,24}').firstMatch(t);
  if (eventLine != null) {
    final line = eventLine.group(0)!.trim();
    if (!isPhotoStyleSummary(line) && !_isNameListHeavy(line)) {
      return line.length > 42 ? '${line.substring(0, 41)}…' : line;
    }
  }

  return '';
}

String _textAfterSubject(String text) {
  final subject = RegExp(r'^[^,.!?]{1,24}?(?:이|가)\s+').firstMatch(text.trim());
  if (subject == null) return text.trim();
  return text.substring(subject.end).trim();
}

List<String> extractPeopleFromMemoryText(String text) {
  final value = text.trim();
  if (value.isEmpty) return [];

  final names = <String>[];
  final seen = <String>{};

  void add(String? raw) {
    if (raw == null) return;
    var token = stripTrailingKoreanParticles(raw.trim());
    token = token.replaceAll(RegExp(r'\s*(?:간호과장|간호팀장|팀장|과장|원장|부장|이사|대리)$'), '').trim();
    if (isSelfPersonToken(token, 'ko')) {
      if (seen.add('나')) names.add('나');
      return;
    }
    if (isFamilyRelationTerm(token)) {
      if (isFamilyTermEmbeddedInCompound(value, token)) return;
      if (seen.add(token)) names.add(token);
      return;
    }
    if (isCompoundParentTerm(token)) {
      if (seen.add(token)) names.add(token);
      return;
    }
    if (isKnownFoodLabel(token) || isKnownContentLabel(token)) return;
    if (isGraphMorphologyJunkToken(token)) return;
    final name = normalizeKoreanPersonName(token);
    if (isBlockedPersonName(name)) return;
    if (!isLikelyKoreanPersonName(name)) return;
    if (seen.add(name)) names.add(name);
  }

  for (final term in extractCompoundParentTermsFromText(value)) {
    add(term);
  }

  for (final term in extractFamilyRelationTermsFromText(value)) {
    add(term);
  }

  for (final match in RegExp(r'([가-힣]{2,4})\s+(?:간호과장|간호팀장|팀장|과장|원장|부장|이사|대리)').allMatches(value)) {
    add(match.group(1));
  }

  for (final match in RegExp(r'로는\s*([^\.]+?)(?=에서\s|이렇게|모두\s*\d|참석하였고\s*보호사|$)').allMatches(value)) {
    _parseNameListSegment(match.group(1)!, add);
  }

  final nurseIdx = value.indexOf('간호사로는');
  if (nurseIdx >= 0) {
    final nurseEnd = value.indexOf('참석하였고', nurseIdx);
    if (nurseEnd > nurseIdx) {
      _parseNameListSegment(value.substring(nurseIdx + '간호사로는'.length, nurseEnd), add);
    }
  }

  final careIdx = value.indexOf('보호사로는');
  if (careIdx >= 0) {
    final careEnd = value.indexOf('이렇게', careIdx);
    final segment = careEnd > careIdx
        ? value.substring(careIdx + '보호사로는'.length, careEnd)
        : value.substring(careIdx + '보호사로는'.length);
    _parseNameListSegment(segment, add);
  }

  for (final name in extractCommaListedKoreanNames(value)) {
    add(name);
  }

  final outingList = RegExp(
    r'\d{4}년\s*\d{1,2}월\s*\d{1,2}일\s+([^.\n]+?)(?=이?\s*(?:이렇게|\d+\s*명))',
  ).firstMatch(value);
  if (outingList != null) {
    for (final part in outingList.group(1)!.split(',')) {
      add(part.trim());
    }
  }

  for (final match in RegExp(r'([가-힣]{2,4})의\s+(?:행동|말|이야기|태도|생각)').allMatches(value)) {
    add(match.group(1));
  }

  final patterns = [
    RegExp(r'([가-힣]{2,4})이하고(?=[\s,.]|$)'),
    RegExp(r'([가-힣]{2,4})(?:이랑|랑|와|과)(?=[\s,.]|$)'),
    // "민수에게", "영희한테"
    RegExp(r'([가-힣]{2,4})(?:에게|한테)(?=\s)'),
    // "영희를 만나"
    RegExp(r'([가-힣]{2,4})(?:을|를)\s+만나'),
    // "지영의 남동생", "민수의 대학 동기"
    RegExp(r'([가-힣]{2,4})의\s+(?:[가-힣]{1,8}\s+)?(?:남동생|여동생|형|누나|오빠|언니|동생|동기|친구)'),
    // "지영은", "민수는", "철수는"
    RegExp(r'([가-힣]{2,4})(?:은|는)(?=[\s,.]|$)'),
    // "민수와 지영은 …" — 뒤쪽 공동 주어.
    RegExp(r'(?:와|과)\s+([가-힣]{2,4})(?:은|는)(?=[\s,.]|$)'),
    RegExp(r'([가-힣]{2,4})(?:님|씨)(?=[\s,.]|$)'),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(value)) {
      add(match.group(1));
    }
  }

  final ranked = rankPeopleForGraph(value, names);
  return _dedupeOrdered(ranked).take(kGraphMaxPeopleSatellites).toList();
}

void _parseNameListSegment(String segment, void Function(String?) add) {
  final cleaned = segment
      .replaceAll(RegExp(r'(?:이|가)\s*참석.*$'), '')
      .replaceAll(RegExp(r'간호사로는.*$'), '')
      .replaceAll(RegExp(r'보호사로는.*$'), '')
      .trim();
  for (final part in cleaned.split(RegExp(r'[,，、]'))) {
    var token = stripTrailingKoreanParticles(part.trim());
    if (token.isEmpty || token == '나') continue;
    token = token.replaceAll(RegExp(r'\s*(?:간호과장|간호팀장|팀장|과장)$'), '').trim();
    if (isFamilyRelationTerm(token)) {
      add(token);
      continue;
    }
    final nameOnly = RegExp(r'^([가-힣]{2,4})').firstMatch(token);
    if (nameOnly != null) {
      add(nameOnly.group(1));
    }
  }
}

List<String> extractPlacesFromMemoryText(String text) {
  final results = <String>[];
  final seen = <String>{};

  void consider(String? raw) {
    final value = raw?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (value.isEmpty || value.length > 24) return;
    if (value.contains('와 ') || value.contains('과 ')) return;
    if (isPersonPlaceCompositeActivity(value)) return;
    final minLen = isGraphVenueToken(value) ? 2 : 3;
    if (value.length < minLen) return;
    if (peopleNoiseInPlace(value)) return;
    if (isMisleadingPlaceChonToken(value)) return;
    if (isGraphMorphologyJunkToken(value)) return;
    if (isJunkEntityOrKeyword(value) || isGraphMetaContent(value)) return;
    if (seen.add(value)) results.add(value);
  }

  for (final match in RegExp(r'(?:와|랑|이랑)\s+([가-힣]{2,12}(?:카페|식당|요리집|술집|병원)?)(?=\s*(?:에서|에\b|에\s))').allMatches(text)) {
    consider(match.group(1));
  }

  for (final match in RegExp(r'([가-힣]{2,8}(?:\s+[가-힣]{2,8})?(?:중화요리집|요리집|식당|카페|병원|클리닉))').allMatches(text)) {
    consider(match.group(1));
  }

  for (final match in RegExp(r'에서\s+([가-힣]{2,8}(?:\s+[가-힣]{2,8})?(?:요리집|식당|카페|중화요리집))').allMatches(text)) {
    consider(match.group(1));
  }

  for (final match in RegExp(r'([가-힣]{2,12}(?:해수욕장|해변|공원|시장|역|천|계곡))').allMatches(text)) {
    consider(match.group(1));
  }

  for (final match in RegExp(r'([가-힣]{2,8}(?:\s+[가-힣]{2,8})?해수욕장)').allMatches(text)) {
    consider(match.group(1));
  }

  for (final match in RegExp(r'([가-힣]{2,8}(?:천|산|강|교|계곡|해변|공원))(?=에\s|에서\s|에$)').allMatches(text)) {
    consider(match.group(1));
  }

  // 단독 장소 토큰: "뒤 카페에 갔다", "카페에서 라떼" 등 (이름 접미사 패턴과 별도).
  for (final match in RegExp(
    r'(?<![가-힣])(카페|식당|술집|편의점|마트|병원|약국|학교|회사|사무실|회의실|강당)(?:에|에서)(?:\s|$)',
  ).allMatches(text)) {
    consider(match.group(1));
  }

  final ocr = extractPlaceHintFromOcr(text);
  if (ocr != null) consider(ocr);

  final atPlace = RegExp(r'([가-힣]{2,10})\s+에서').firstMatch(text);
  if (atPlace != null && _looksLikePlaceLabel(atPlace.group(1)!)) {
    consider(atPlace.group(1));
  }

  if (results.isEmpty) {
    const suffix = '해수욕장';
    final idx = text.indexOf(suffix);
    if (idx >= 2) {
      var start = idx;
      while (start > 0 && RegExp(r'[가-힣 ]').hasMatch(text[start - 1])) {
        start--;
      }
      final place = text.substring(start, idx + suffix.length).trim();
      if (place.length >= suffix.length && place.length <= 24 && seen.add(place)) {
        results.add(place);
      }
    }
  }

  return results;
}

bool peopleNoiseInPlace(String value) {
  return RegExp(r'(?:참석|보호사|간호사|이동|서충|이렇게|명이서|식구|\d)').hasMatch(value);
}

bool _looksLikePlaceLabel(String word) {
  final value = word.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (isInternalMemoryEntityTag(value)) return false;
  if (isPersonPlaceCompositeActivity(value)) return false;
  if (looksLikeKoreanPlaceName(value)) return true;
  if (RegExp(r'(?:요리집|식당|카페|병원|역|해수욕장|해변)$').hasMatch(value)) return true;
  if (value.contains(' ') && RegExp(r'(?:해수욕장|해변|공원|요리집|식당)$').hasMatch(value)) return true;
  return false;
}

/// 카페·식당 등 관계망에서 장소로 취급하는 짧은 장소 토큰.
bool isGraphVenueToken(String word) {
  final value = word.trim();
  if (value.isEmpty) return false;
  if (_looksLikePlaceLabel(value)) return true;
  const venues = {
    '카페', '식당', '술집', '편의점', '마트', '병원', '약국', '학교', '회사', '사무실', '회의실', '강당',
  };
  return venues.contains(value);
}

bool _looksLikeGraphPersonToken(String token) {
  if (isKnownFoodLabel(token) || isKnownContentLabel(token)) return false;
  if (isFamilyRelationTerm(token) || isCompoundParentTerm(token)) return true;
  return isLikelyKoreanPersonName(token) && !isGraphFoodOrNoiseToken(token);
}

bool _isPersonPersonCompositeActivity(String activity) {
  final m = RegExp(r'^([가-힣]{2,12})와\s+([가-힣]{2,12})$').firstMatch(activity.trim());
  if (m == null) return false;
  final left = stripTrailingKoreanParticles(m.group(1)!);
  final right = stripTrailingKoreanParticles(m.group(2)!);
  if (isGraphFoodOrNoiseToken(left) || isGraphFoodOrNoiseToken(right)) return false;
  if (isGraphVenueToken(right) || _looksLikePlaceLabel(right)) return false;
  return _looksLikeGraphPersonToken(left) && _looksLikeGraphPersonToken(right);
}

bool _isPersonPlaceCompositeActivity(String activity) {
  if (_isPersonPersonCompositeActivity(activity)) return true;
  final m = RegExp(r'^([가-힣]{2,8})와\s+(.+)$').firstMatch(activity.trim());
  if (m == null) return false;
  final tail = m.group(2)!.trim();
  return isGraphVenueToken(tail) || _looksLikePlaceLabel(tail);
}

/// 관계망 위성으로 노출할 라벨인지 (내부 태그·인물+장소 합성 제외).
bool isPersonPlaceCompositeActivity(String activity) => _isPersonPlaceCompositeActivity(activity);

/// 저장된 entities에 남아 있어도 현재 본문·요약에 없으면 관계망에서 제외합니다.
bool entityLabelReferencedInMemory(String label, Memory memory) {
  final norm = label.trim();
  if (norm.isEmpty) return false;
  final blob = '${memory.summary}\n${memory.content}'.trim();
  if (blob.isEmpty) return false;
  if (blob.contains(norm)) return true;
  if (memoryTextsOverlapForDisplay(norm, blob)) return true;
  if (isFamilyRelationTerm(norm)) {
    return RegExp('${RegExp.escape(norm)}(?:과|와|랑|이랑|하고|이|가|님|씨)?(?=[\\s,.]|\$)').hasMatch(blob);
  }
  final canonical = normalizeKoreanPersonName(stripTrailingKoreanParticles(norm));
  if (canonical != norm && blob.contains(canonical)) return true;
  return false;
}

const _graphKeepSatelliteKeywords = {
  '시험', '공부', '회식', '여행', '운동', '식사', '모임', '회의', '생일', '결혼식', '졸업식',
  '컴퓨터', '컴퓨터 활용 능력',
};

bool _isChipStyleHubTitle(String hub) {
  final h = hub.replaceAll(RegExp(r'[.!?…]+$'), '').trim();
  if (!h.contains('·')) return false;
  final parts = h.split('·').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (parts.length < 2 || h.length > kHubTitleMaxLen + 4) return false;
  return parts.every((p) => p.length <= 14 && !p.contains('와') && !p.contains('에서'));
}

bool shouldShowGraphSatelliteLabel(String label, {String? hubTitle}) {
  final v = label.trim();
  if (v.isEmpty || isInternalMemoryEntityTag(v)) return false;
  if (isPersonPlaceCompositeActivity(v)) return false;
  final hub = hubTitle?.trim() ?? '';
  if (hub.isNotEmpty && _isChipStyleHubTitle(hub)) return true;
  if (hub.isNotEmpty) {
    if (hub == v) return false;
    // 가족 호칭(아들·딸 등) — 허브가 긴 문장일 때만 별도 위성 유지.
    if (isFamilyRelationTerm(v)) {
      if (hub.length <= v.length + 2) return false;
      return true;
    }
    if (isCompoundParentTerm(v)) {
      if (hub.length <= v.length + 2) return false;
      return true;
    }
    if (isKnownFoodLabel(v)) return true;
    // 장소만 제목 중복 시 위성 생략 (카페·집 등).
    if ((_looksLikePlaceLabel(v) || isGraphVenueToken(v)) &&
        v.length <= 8 &&
        !_graphKeepSatelliteKeywords.contains(v)) {
      return !(v.length >= 2 && hub.contains(v));
    }
    if (v.length >= 2 && hub.contains(v)) {
      if (isFamilyRelationTerm(v)) {
        if (hub.length <= v.length + 2) return false;
        return true;
      }
      if (_looksLikePlaceLabel(v) || isGraphVenueToken(v)) {
        return false;
      }
      if (isLikelyKoreanPersonName(v) && !_graphKeepSatelliteKeywords.contains(v)) {
        return false;
      }
      if (hub.length > v.length + 6) return true;
      return false;
    }
  }
  return true;
}

/// 타임라인·검색·그래프 인사이트용 사용자 노출 엔티티.
List<String> userVisibleEntityLabels(
  Memory memory, {
  String? hubTitle,
  String localeCode = 'ko',
  GraphMemoryFragment? aiFragment,
}) {
  final bundle = extractMemoryEntities(
    memory,
    localeCode: localeCode,
    aiFragment: aiFragment,
  );

  final fromContent = <String>[
    ...bundle.people,
    ...bundle.places,
    ...bundle.organizations,
    ...bundle.activities,
    ...bundle.events,
    ...bundle.interests,
    ...bundle.contents,
    ...bundle.food,
    ...bundle.hobbies,
    ...bundle.emotions,
  ];

  final fromStored = sanitizeEntities(memory.entities).where((e) {
    if (isLatLngLabel(e)) return false;
    if (isInternalMemoryEntityTag(e)) return false;
    if (isPersonPlaceCompositeActivity(e)) return false;
    return entityLabelReferencedInMemory(e, memory);
  });

  final seen = <String>{};
  final out = <String>[];
  for (final raw in [...fromContent, ...fromStored]) {
    final label = raw.trim();
    if (label.isEmpty) continue;
    if (isInternalMemoryEntityTag(label)) continue;
    if (isPersonPlaceCompositeActivity(label)) continue;
    // 그래프 위성 전용 중복 숨김 — 타임라인·검색 칩은 hubTitle 미전달 시 생략.
    if (hubTitle != null && !shouldShowGraphSatelliteLabel(label, hubTitle: hubTitle)) continue;
    if (seen.add(label)) out.add(label);
  }
  return out;
}

List<String> _extractActivitiesFromContent(
  String content,
  List<String> people,
  List<String> entities,
) {
  final out = <String>[];

  if (RegExp(r'고스톰|고스돔|고도리').hasMatch(content)) {
    out.add('고스톰');
  }
  if (RegExp(r'다슬기(?:를)?\s*잡').hasMatch(content)) {
    out.add('다슬기 잡기');
  } else if (content.contains('다슬기')) {
    out.add('다슬기');
  }

  for (final match in RegExp(r'([가-힣]{2,8})와\s+([가-힣]{2,12})').allMatches(content)) {
    final left = normalizeKoreanPersonName(stripTrailingKoreanParticles(match.group(1)!));
    var tail = stripTrailingKoreanParticles(match.group(2)!.trim());
    if (_looksLikeGraphPersonToken(left) && _looksLikeGraphPersonToken(tail)) continue;
    if (!isFamilyRelationTerm(left) && !isLikelyKoreanPersonName(left)) continue;
    if (isGraphVenueToken(tail) || _looksLikePlaceLabel(tail)) continue;
    if (isGraphMealCompanionToken(tail)) continue;
    if (!isFamilyRelationTerm(tail) && !isLikelyKoreanPersonName(tail)) continue;
    if (isGraphFoodOrNoiseToken(tail) || tail == '술') continue;
    out.add('$left와 $tail');
  }

  const leisureActivities = ['일몰', '산책', '관람', '나들이'];
  for (final activity in leisureActivities) {
    if (content.contains(activity)) out.add(activity);
  }

  const eventActivities = ['여행', '회식', '회의', '교육', '워크숍', '시험', '공부'];
  for (final activity in eventActivities) {
    if (content.contains(activity)) out.add(activity);
  }

  return out;
}

List<String> extractOrganizationsFromText(String text, {String localeCode = 'ko'}) {
  final orgs = <String>[];
  final seen = <String>{};
  void add(String o) {
    if (seen.add(o)) orgs.add(o);
  }

  if (RegExp(r'병원').hasMatch(text)) add(localeCode == 'ko' ? '병원' : 'Hospital');
  if (RegExp(r'간호과').hasMatch(text)) add(localeCode == 'ko' ? '간호과' : 'Nursing dept');
  if (RegExp(r'보호사(?:로는|들|와|과)').hasMatch(text)) {
    add(localeCode == 'ko' ? '보호사' : 'Care workers');
  }
  for (final match in RegExp(
    r'([가-힣A-Za-z0-9]{2,12}(?:전자|그룹|은행|회사|병원|학교|대학교))(?:에서|에)\s+',
  ).allMatches(text)) {
    add(match.group(1)!);
  }
  return orgs;
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

bool _isNameListHeavy(String line) {
  final commas = ','.allMatches(line).length;
  return commas >= 4 && !line.contains('회식') && !line.contains('회의');
}

/// entityKeysForMemory·브리지용 키 집합.
Set<String> entityKeysFromBundle(MemoryEntityBundle bundle) {
  final keys = <String>{};
  for (final p in bundle.people) {
    keys.add('person::$p');
  }
  for (final p in bundle.places) {
    keys.add('place::$p');
  }
  for (final o in bundle.organizations) {
    keys.add('organization::$o');
  }
  for (final a in bundle.activities) {
    keys.add('activity::$a');
  }
  for (final e in bundle.events) {
    keys.add('event::$e');
  }
  for (final i in bundle.interests) {
    keys.add('interest::$i');
  }
  for (final c in bundle.contents) {
    keys.add('content::$c');
  }
  for (final f in bundle.food) {
    keys.add('food::$f');
  }
  for (final h in bundle.hobbies) {
    keys.add('hobby::$h');
  }
  for (final e in bundle.emotions) {
    keys.add('emotion::$e');
  }
  if (bundle.eventTitle.isNotEmpty) {
    keys.add('event::${bundle.eventTitle}');
  }
  return keys;
}
