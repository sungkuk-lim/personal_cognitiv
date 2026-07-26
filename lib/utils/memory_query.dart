import '../models/memory.dart';
import '../features/graph/graph_chat_save.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';
import 'memory_keyword_ui.dart';
import 'memory_theme_tags.dart';
import 'memory_graph_semantics.dart';
import 'memory_semantic_extract.dart';
import 'semantic_search.dart';

/// 복합 검색 조건 — Phase A~D 공통.
class MemoryQuery {
  const MemoryQuery({
    this.people = const [],
    this.places = const [],
    this.emotions = const [],
    this.activities = const [],
    this.foods = const [],
    this.hobbies = const [],
    this.interests = const [],
    this.seasons = const [],
    this.weathers = const [],
    this.hasPhoto,
    this.hasVideo,
    this.subCategory,
    this.dateStart,
    this.dateEnd,
    this.freeText = '',
  });

  final List<String> people;
  final List<String> places;
  final List<String> emotions;
  final List<String> activities;
  final List<String> foods;
  final List<String> hobbies;
  final List<String> interests;
  final List<String> seasons;
  final List<String> weathers;
  final bool? hasPhoto;
  final bool? hasVideo;
  final String? subCategory;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String freeText;

  bool get isComposite =>
      people.isNotEmpty ||
      places.isNotEmpty ||
      emotions.isNotEmpty ||
      activities.isNotEmpty ||
      foods.isNotEmpty ||
      hobbies.isNotEmpty ||
      interests.isNotEmpty ||
      seasons.isNotEmpty ||
      weathers.isNotEmpty ||
      hasPhoto == true ||
      hasVideo == true ||
      (subCategory != null && subCategory!.isNotEmpty) ||
      dateStart != null ||
      dateEnd != null;

  bool get isEmpty => !isComposite && freeText.trim().isEmpty;

  MemoryQuery copyWith({
    List<String>? people,
    List<String>? places,
    List<String>? emotions,
    List<String>? activities,
    List<String>? foods,
    List<String>? hobbies,
    List<String>? interests,
    List<String>? seasons,
    List<String>? weathers,
    bool? hasPhoto,
    bool? hasVideo,
    String? subCategory,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? freeText,
    bool clearPhoto = false,
    bool clearVideo = false,
  }) {
    return MemoryQuery(
      people: people ?? this.people,
      places: places ?? this.places,
      emotions: emotions ?? this.emotions,
      activities: activities ?? this.activities,
      foods: foods ?? this.foods,
      hobbies: hobbies ?? this.hobbies,
      interests: interests ?? this.interests,
      seasons: seasons ?? this.seasons,
      weathers: weathers ?? this.weathers,
      hasPhoto: clearPhoto ? null : (hasPhoto ?? this.hasPhoto),
      hasVideo: clearVideo ? null : (hasVideo ?? this.hasVideo),
      subCategory: subCategory ?? this.subCategory,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      freeText: freeText ?? this.freeText,
    );
  }

  MemoryQuery removeChip(String chipId) {
    if (chipId == 'photo') return copyWith(clearPhoto: true);
    if (chipId == 'video') return copyWith(clearVideo: true);
    if (chipId.startsWith('person:')) {
      final v = chipId.substring('person:'.length);
      return copyWith(people: people.where((p) => p != v).toList());
    }
    if (chipId.startsWith('place:')) {
      final v = chipId.substring('place:'.length);
      return copyWith(places: places.where((p) => p != v).toList());
    }
    if (chipId.startsWith('emotion:')) {
      final v = chipId.substring('emotion:'.length);
      return copyWith(emotions: emotions.where((p) => p != v).toList());
    }
    if (chipId.startsWith('activity:')) {
      final v = chipId.substring('activity:'.length);
      return copyWith(activities: activities.where((p) => p != v).toList());
    }
    if (chipId.startsWith('food:')) {
      final v = chipId.substring('food:'.length);
      return copyWith(foods: foods.where((p) => p != v).toList());
    }
    if (chipId.startsWith('hobby:')) {
      final v = chipId.substring('hobby:'.length);
      return copyWith(hobbies: hobbies.where((p) => p != v).toList());
    }
    if (chipId.startsWith('interest:')) {
      final v = chipId.substring('interest:'.length);
      return copyWith(interests: interests.where((p) => p != v).toList());
    }
    if (chipId.startsWith('season:')) {
      final v = chipId.substring('season:'.length);
      return copyWith(seasons: seasons.where((p) => p != v).toList());
    }
    if (chipId.startsWith('weather:')) {
      final v = chipId.substring('weather:'.length);
      return copyWith(weathers: weathers.where((p) => p != v).toList());
    }
    if (chipId.startsWith('category:')) {
      return copyWith(subCategory: '');
    }
    return this;
  }
}

class MemoryQueryChip {
  const MemoryQueryChip({required this.id, required this.label, required this.iconName});

  final String id;
  final String label;
  final String iconName;
}

List<MemoryQueryChip> memoryQueryChips(MemoryQuery query, {String localeCode = 'ko'}) {
  final chips = <MemoryQueryChip>[];
  for (final p in query.people) {
    chips.add(MemoryQueryChip(id: 'person:$p', label: p, iconName: 'person'));
  }
  for (final p in query.places) {
    chips.add(MemoryQueryChip(id: 'place:$p', label: p, iconName: 'place'));
  }
  for (final e in query.emotions) {
    chips.add(MemoryQueryChip(id: 'emotion:$e', label: e, iconName: 'emotion'));
  }
  for (final a in query.activities) {
    chips.add(MemoryQueryChip(id: 'activity:$a', label: a, iconName: 'activity'));
  }
  for (final f in query.foods) {
    chips.add(MemoryQueryChip(id: 'food:$f', label: f, iconName: 'food'));
  }
  for (final h in query.hobbies) {
    chips.add(MemoryQueryChip(id: 'hobby:$h', label: h, iconName: 'hobby'));
  }
  for (final i in query.interests) {
    chips.add(MemoryQueryChip(id: 'interest:$i', label: i, iconName: 'interest'));
  }
  for (final s in query.seasons) {
    chips.add(MemoryQueryChip(id: 'season:$s', label: s, iconName: 'season'));
  }
  for (final w in query.weathers) {
    chips.add(MemoryQueryChip(id: 'weather:$w', label: w, iconName: 'weather'));
  }
  if (query.hasPhoto == true) {
    chips.add(MemoryQueryChip(
      id: 'photo',
      label: localeCode == 'ko' ? '사진' : 'Photos',
      iconName: 'photo',
    ));
  }
  if (query.hasVideo == true) {
    chips.add(MemoryQueryChip(
      id: 'video',
      label: localeCode == 'ko' ? '동영상' : 'Video',
      iconName: 'video',
    ));
  }
  if (query.subCategory != null && query.subCategory!.isNotEmpty) {
    chips.add(MemoryQueryChip(
      id: 'category:${query.subCategory}',
      label: query.subCategory!,
      iconName: 'category',
    ));
  }
  return chips;
}

/// 자연어 → 구조화 쿼리 (규칙 기반 1차).
MemoryQuery parseNaturalLanguageQuery(String raw, {String localeCode = 'ko'}) {
  final q = raw.trim();
  if (q.isEmpty) return const MemoryQuery();

  final isKo = localeCode == 'ko';
  var remaining = q;

  bool? hasPhoto;
  bool? hasVideo;
  if (_hasMediaIntent(q, isKo, photo: true)) {
    hasPhoto = true;
    remaining = _stripMediaWords(remaining, isKo, photo: true);
  }
  if (_hasMediaIntent(q, isKo, photo: false)) {
    hasVideo = true;
    remaining = _stripMediaWords(remaining, isKo, photo: false);
  }

  final emotions = _pickLexicon(q, kEmotionLexicon);
  final activities = _pickLexicon(q, kQueryActivityLexicon);
  final foods = _pickLexicon(q, kFoodLexicon);

  final people = <String>[];
  for (final term in koreanFamilyRelationTerms) {
    if (q.contains(term)) people.add(term);
  }
  for (final match in RegExp(
    r'([가-힣]{2,5})(?:와|과|랑|이랑|하고|와함께|이랑함께|님과|님랑|이가|가)',
  ).allMatches(q)) {
    final token = normalizeKoreanPersonName(match.group(1)!.trim());
    if (token.length >= 2 &&
        isLikelyKoreanPersonName(token) &&
        !isKnownInterestLabel(token) &&
        !kEmotionLexicon.contains(token) &&
        !kQueryActivityLexicon.contains(token) &&
        !kFoodLexicon.contains(token)) {
      people.add(token);
    }
  }
  for (final match in RegExp(r'([가-힣]{2,5})이(?=\s|함께|에서|와|과|랑|$)').allMatches(q)) {
    final token = normalizeKoreanPersonName(match.group(1)!.trim());
    if (token.length >= 2 &&
        isLikelyKoreanPersonName(token) &&
        !isKnownInterestLabel(token) &&
        !kEmotionLexicon.contains(token) &&
        !kQueryActivityLexicon.contains(token) &&
        !kFoodLexicon.contains(token)) {
      people.add(token);
    }
  }
  for (final match in RegExp(r'[가-힣]{2,4}').allMatches(q)) {
    final token = match.group(0)!;
    if (isLikelyKoreanPersonName(token) &&
        !isKnownInterestLabel(token) &&
        !kEmotionLexicon.contains(token) &&
        !kActivityLexicon.contains(token)) {
      people.add(normalizeKoreanPersonName(token));
    }
  }

  final hobbies = _pickLexicon(q, kHobbyLexicon);
  final interests = _pickLexicon(q, kSemanticInterestLexicon);
  final seasons = _pickLexicon(q, kSeasonLexicon);
  final weathers = _pickLexicon(q, kWeatherLexicon);

  final activityExtras = <String>[];
  if (RegExp(r'영화를?\s*봤|영화\s*관람|영화\s*본').hasMatch(q)) activityExtras.add('영화');
  if (RegExp(r'공연을?\s*봤|공연\s*관람').hasMatch(q)) activityExtras.add('공연');
  if (RegExp(r'산책').hasMatch(q)) activityExtras.add('산책');
  final mergedActivities = _dedupeStrings([...activities, ...activityExtras]);

  final places = <String>[];
  for (final match in RegExp(r'[가-힣]{2,12}(?:해수욕장|해변|공원|카페|식당|역)?').allMatches(q)) {
    final token = match.group(0)!.trim();
    if (token.length >= 2 && (looksLikeKoreanPlaceName(token) || isGraphVenueToken(token))) {
      places.add(token);
    }
  }
  // 「먹었던 식당」「갔던 카페」— 자연어 장소 의도
  for (final match in RegExp(
    r'(?:먹었던|갔던|방문한|들른)\s*([가-힣]{2,12}(?:식당|카페|술집|병원|공원|해수욕장|해변)?)',
  ).allMatches(q)) {
    final token = match.group(1)!.trim();
    if (token.length >= 2) places.add(token);
  }
  if (RegExp(r'식당|밥집|맛집').hasMatch(q) && !places.any((p) => p.contains('식당'))) {
    places.add('식당');
  }

  String? subCategory;
  final catMap = isKo
      ? {'가족': '가족', '친구': '친구', '연인': '연인', '여행': '여행', '회사': '회사', '공부': '공부'}
      : {'family': 'Family', 'friend': 'Friends', 'partner': 'Partner', 'travel': 'Travel', 'work': 'Work'};
  for (final e in catMap.entries) {
    if (q.toLowerCase().contains(e.key.toLowerCase())) {
      subCategory = e.value;
      break;
    }
  }

  final (dateStart, dateEnd) = _parseDateRange(q, isKo);

  final freeText = remaining
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'(?:만|보여|찾아|검색|모아|추천|알려)\s*$'), '')
      .trim();

  return MemoryQuery(
    people: _dedupeStrings(people),
    places: _dedupeStrings(places),
    emotions: emotions,
    activities: mergedActivities,
    foods: foods,
    hobbies: hobbies,
    interests: interests,
    seasons: seasons,
    weathers: weathers,
    hasPhoto: hasPhoto,
    hasVideo: hasVideo,
    subCategory: subCategory,
    dateStart: dateStart,
    dateEnd: dateEnd,
    freeText: freeText,
  );
}

bool _hasMediaIntent(String q, bool isKo, {required bool photo}) {
  if (photo) {
    return q.contains(isKo ? '사진' : 'photo') ||
        q.contains(isKo ? '촬영' : 'picture') ||
        q.contains(isKo ? '찍은' : 'shot');
  }
  return q.contains(isKo ? '동영상' : 'video') || q.contains(isKo ? '영상' : 'clip');
}

String _stripMediaWords(String s, bool isKo, {required bool photo}) {
  final words = photo
      ? [if (isKo) '사진', if (isKo) '촬영', if (isKo) '찍은', 'photo', 'picture', 'shot']
      : [if (isKo) '동영상', if (isKo) '영상', 'video', 'clip'];
  var out = s;
  for (final w in words) {
    out = out.replaceAll(w, '');
  }
  return out;
}

List<String> _pickLexicon(String q, Set<String> lexicon) {
  return lexicon.where((w) => q.contains(w)).toList();
}

List<String> _dedupeStrings(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    if (seen.add(item)) out.add(item);
  }
  return out;
}

(DateTime?, DateTime?) _parseDateRange(String q, bool isKo) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  if (q.contains(isKo ? '오늘' : 'today')) {
    return (todayStart, todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
  }
  if (q.contains(isKo ? '어제' : 'yesterday')) {
    final y = todayStart.subtract(const Duration(days: 1));
    return (y, todayStart.subtract(const Duration(milliseconds: 1)));
  }
  if (q.contains(isKo ? '그제' : 'day before yesterday') || q.contains('그저께')) {
    final d = todayStart.subtract(const Duration(days: 2));
    return (d, d.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
  }
  if (q.contains(isKo ? '이번 주' : 'this week') || q.contains(isKo ? '이번주' : 'this week')) {
    final weekday = now.weekday; // 1=Mon
    final weekStart = todayStart.subtract(Duration(days: weekday - 1));
    return (weekStart, null);
  }
  if (q.contains(isKo ? '지난달' : 'last month') || q.contains(isKo ? '저번달' : 'last month')) {
    final firstThis = DateTime(now.year, now.month, 1);
    final firstLast = DateTime(now.year, now.month - 1, 1);
    return (firstLast, firstThis.subtract(const Duration(milliseconds: 1)));
  }
  if (q.contains(isKo ? '작년' : 'last year')) {
    return (DateTime(now.year - 1), DateTime(now.year, 1, 1).subtract(const Duration(milliseconds: 1)));
  }
  if (q.contains(isKo ? '올해' : 'this year')) {
    return (DateTime(now.year), null);
  }
  final recent = RegExp(isKo ? r'최근\s*(\d+)\s*일' : r'last\s*(\d+)\s*days').firstMatch(q);
  if (recent != null) {
    final days = int.tryParse(recent.group(1)!) ?? 7;
    return (now.subtract(Duration(days: days)), null);
  }
  final monthDay = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일?').firstMatch(q);
  if (monthDay != null) {
    final m = int.tryParse(monthDay.group(1)!) ?? now.month;
    final d = int.tryParse(monthDay.group(2)!) ?? now.day;
    final start = DateTime(now.year, m, d);
    return (start, start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
  }
  return (null, null);
}

bool memoryMatchesQuery(
  Memory memory,
  MemoryQuery query, {
  String localeCode = 'ko',
  bool Function(String memoryId)? hasPhotoFor,
  bool Function(String memoryId)? hasVideoFor,
}) {
  if (!isUserFacingMemory(memory)) return false;

  if (query.dateStart != null && memory.createdAt.isBefore(query.dateStart!)) return false;
  if (query.dateEnd != null && memory.createdAt.isAfter(query.dateEnd!)) return false;

  if (query.subCategory != null && query.subCategory!.isNotEmpty) {
    if (memory.subCategory != query.subCategory && !memory.subCategory.contains(query.subCategory!)) {
      return false;
    }
  }

  if (query.hasPhoto == true) {
    final ok = memory.type == 'image' || (hasPhotoFor?.call(memory.id) ?? false);
    if (!ok) return false;
  }
  if (query.hasVideo == true) {
    final ok = (hasVideoFor?.call(memory.id) ?? false);
    if (!ok) return false;
  }

  for (final person in query.people) {
    if (!memoryMatchesKeyword(memory, person, localeCode: localeCode)) return false;
  }
  for (final place in query.places) {
    if (!memoryMatchesKeyword(memory, place, localeCode: localeCode)) return false;
  }
  for (final emotion in query.emotions) {
    if (!memoryHasThemeTag(memory, kTagEmotionPrefix, emotion) &&
        !memory.content.contains(emotion) &&
        !memory.summary.contains(emotion)) {
      return false;
    }
  }
  for (final activity in query.activities) {
    final acts = activityTagsForMemory(memory, localeCode: localeCode);
    if (!acts.any((a) => a.contains(activity) || activity.contains(a)) &&
        !memory.content.contains(activity)) {
      return false;
    }
  }
  for (final food in query.foods) {
    if (!memoryHasThemeTag(memory, kTagFoodPrefix, food) && !memory.content.contains(food)) return false;
  }
  for (final hobby in query.hobbies) {
    if (!memoryHasThemeTag(memory, kTagHobbyPrefix, hobby) && !memory.content.contains(hobby)) return false;
  }
  for (final interest in query.interests) {
    final tags = interestTagsForMemory(memory, localeCode: localeCode);
    if (!tags.any((t) => t.contains(interest) || interest.contains(t)) &&
        !memory.content.contains(interest) &&
        !memory.summary.contains(interest)) {
      return false;
    }
  }
  for (final season in query.seasons) {
    if (!memoryHasThemeTag(memory, kTagSeasonPrefix, season) && !memory.content.contains(season)) return false;
  }
  for (final weather in query.weathers) {
    if (!memoryHasThemeTag(memory, kTagWeatherPrefix, weather) && !memory.content.contains(weather)) {
      return false;
    }
  }

  return true;
}

List<Memory> filterMemoriesByQuery(
  List<Memory> memories,
  MemoryQuery query, {
  String localeCode = 'ko',
  bool Function(String memoryId)? hasPhotoFor,
  bool Function(String memoryId)? hasVideoFor,
  int limit = 24,
}) {
  if (query.isEmpty) return [];
  final list = memories
      .where((m) => memoryMatchesQuery(
            m,
            query,
            localeCode: localeCode,
            hasPhotoFor: hasPhotoFor,
            hasVideoFor: hasVideoFor,
          ))
      .toList();
  list.sort((a, b) {
    final imp = importanceForMemory(b).compareTo(importanceForMemory(a));
    if (imp != 0) return imp;
    return b.createdAt.compareTo(a.createdAt);
  });
  return list.take(limit).toList();
}

/// 복합 쿼리 우선 → 부족하면 하이브리드 검색 보강.
List<Memory> searchWithMemoryQuery({
  required List<Memory> memories,
  required MemoryQuery query,
  required String localeCode,
  bool Function(String memoryId)? hasPhotoFor,
  bool Function(String memoryId)? hasVideoFor,
  List<double>? queryEmbedding,
  int limit = 12,
}) {
  if (query.isComposite) {
    final strict = filterMemoriesByQuery(
      memories,
      query,
      localeCode: localeCode,
      hasPhotoFor: hasPhotoFor,
      hasVideoFor: hasVideoFor,
      limit: limit,
    );
    if (strict.isNotEmpty) return strict.take(limit).toList();
  }

  final text = query.freeText.trim().isNotEmpty ? query.freeText.trim() : _reconstructText(query);
  if (text.isEmpty) return [];

  return searchMemoriesHybrid(
    memories: memories,
    query: text,
    queryEmbedding: queryEmbedding,
    limit: limit,
  );
}

String _reconstructText(MemoryQuery query) {
  return [
    ...query.people,
    ...query.places,
    ...query.emotions,
    ...query.activities,
    ...query.foods,
    ...query.hobbies,
    ...query.interests,
    ...query.seasons,
    ...query.weathers,
    if (query.subCategory != null) query.subCategory!,
  ].join(' ');
}

String describeMemoryQuery(MemoryQuery query, {String localeCode = 'ko'}) {
  if (query.isEmpty) return '';
  final parts = <String>[];
  if (query.people.isNotEmpty) parts.add(query.people.join('·'));
  if (query.places.isNotEmpty) parts.add(query.places.join('·'));
  if (query.emotions.isNotEmpty) parts.add(query.emotions.join('·'));
  if (query.activities.isNotEmpty) parts.add(query.activities.join('·'));
  if (query.foods.isNotEmpty) parts.add(query.foods.join('·'));
  if (query.interests.isNotEmpty) parts.add(query.interests.join('·'));
  if (query.hasPhoto == true) parts.add(localeCode == 'ko' ? '사진' : 'photos');
  final joined = parts.where((p) => p.isNotEmpty).join(' + ');
  if (localeCode == 'ko') return '「$joined」 조건에 맞는 기억';
  return 'Memories matching: $joined';
}
