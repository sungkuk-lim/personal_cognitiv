import '../models/memory.dart';
import 'korean_person_names.dart';
import 'memory_entity_edit.dart';
import 'memory_entity_extract.dart';
import 'memory_semantic_extract.dart';
import 'ocr_utils.dart';

/// 엔티티에 저장하는 테마 태그 접두사 (스키마 변경 없이 Phase B~D 지원).
const String kTagEmotionPrefix = 'tag:emotion:';
const String kTagActivityPrefix = 'tag:activity:';
const String kTagFoodPrefix = 'tag:food:';
const String kTagHobbyPrefix = 'tag:hobby:';
const String kTagSeasonPrefix = 'tag:season:';
const String kTagWeatherPrefix = 'tag:weather:';
const String kTagEventPrefix = 'tag:event:';
const String kTagInterestPrefix = 'tag:interest:';
const String kTagContentPrefix = 'tag:content:';
const kEmotionLexicon = {
  '행복', '기쁨', '슬픔', '감동', '그리움', '설렘', '후회', '감사', '실망', '평온', '즐거움', '뿌듯', '의문',
};
const kActivityLexicon = {
  '산책', '여행', '회식', '회의', '나들이', '운동', '관람', '쇼핑',
};

/// 자연어 검색·필터용 — 그래프 위성과 달리 식사·식사 시간대 포함.
const kQueryActivityLexicon = {
  ...kActivityLexicon,
  '식사', '저녁', '점심', '아침', '간식', '브런치',
};
const kFoodLexicon = {
  '탕수육', '자장면', '치킨', '삼겹살', '장어', '조개', '회', '라면', '피자', '커피', '빵', '떡볶이',
};
const kHobbyLexicon = {
  '등산', '독서', '게임', '캠핑', '낚시', '요리', '사진', '그림', '음악', '영화', '러닝', '수영',
};
const kSeasonLexicon = {'봄', '여름', '가을', '겨울'};
const kWeatherLexicon = {
  '비', '눈', '맑', '흐림', '더운', '추운', '바람', '장마', '무더위', '폭우', '눈보라',
};

List<String> emotionTagsForMemory(Memory memory, {String localeCode = 'ko'}) {
  return _readTags(memory, kTagEmotionPrefix, () => _scanLexicon(memory, kEmotionLexicon));
}

List<String> activityTagsForMemory(Memory memory, {String localeCode = 'ko'}) {
  final fromTags = _readTags(memory, kTagActivityPrefix, () => <String>[]);
  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  return _dedupe([...fromTags, ...bundle.activities]);
}

List<String> foodTagsForMemory(Memory memory) {
  return _readTags(memory, kTagFoodPrefix, () => _scanLexicon(memory, kFoodLexicon));
}

List<String> hobbyTagsForMemory(Memory memory) {
  return _readTags(memory, kTagHobbyPrefix, () => _scanLexicon(memory, kHobbyLexicon));
}

List<String> interestTagsForMemory(Memory memory, {String localeCode = 'ko'}) {
  return _readTags(memory, kTagInterestPrefix, () {
    final bundle = extractMemoryEntities(memory, localeCode: localeCode);
    return _dedupe([...bundle.interests, ..._scanLexicon(memory, kSemanticInterestLexicon)]);
  });
}

List<String> seasonTagsForMemory(Memory memory) {
  return _readTags(memory, kTagSeasonPrefix, () => _scanLexicon(memory, kSeasonLexicon));
}

List<String> weatherTagsForMemory(Memory memory) {
  return _readTags(memory, kTagWeatherPrefix, () => _scanLexicon(memory, kWeatherLexicon));
}

List<String> _readTags(Memory memory, String prefix, List<String> Function() fallback) {
  final fromEntities = memory.entities
      .where((e) => e.startsWith(prefix))
      .map((e) => e.substring(prefix.length).trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (fromEntities.isNotEmpty) return fromEntities;
  return fallback();
}

List<String> _scanLexicon(Memory memory, Set<String> lexicon) {
  final text = '${memory.content}\n${memory.summary}\n${memory.userMemo}';
  return lexicon.where((w) => text.contains(w)).toList();
}

List<String> _dedupe(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    final key = item.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(key);
  }
  return out;
}

bool memoryHasThemeTag(Memory memory, String prefix, String label) {
  final needle = label.trim();
  if (needle.isEmpty) return false;
  for (final e in memory.entities) {
    if (e == '$prefix$needle') return true;
  }
  final text = '${memory.content} ${memory.summary} ${memory.userMemo}';
  return text.contains(needle);
}

/// 저장 직전 본문에서 감정·활동·음식·취미·계절·날씨 태그를 엔티티에 병합합니다.
Memory enrichMemoryWithThemeTags(Memory memory, {String localeCode = 'ko'}) {
  final extras = <String>[];
  void addPrefixed(String prefix, Iterable<String> labels) {
    for (final label in labels) {
      final tag = '$prefix$label';
      if (!memory.entities.contains(tag)) extras.add(tag);
    }
  }

  addPrefixed(kTagEmotionPrefix, _scanLexicon(memory, kEmotionLexicon).take(2));
  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  final semantic = extractSemanticFromText(memory.content);
  addPrefixed(kTagActivityPrefix, bundle.activities.take(2));
  addPrefixed(kTagEventPrefix, [...bundle.events, ...semantic.events].take(2));
  addPrefixed(kTagInterestPrefix, [...bundle.interests, ...semantic.interests].take(2));
  addPrefixed(kTagContentPrefix, [...bundle.contents, ...semantic.contents].take(2));
  addPrefixed(kTagFoodPrefix, _scanLexicon(memory, kFoodLexicon).take(2));
  addPrefixed(kTagHobbyPrefix, _scanLexicon(memory, kHobbyLexicon).take(2));  addPrefixed(kTagSeasonPrefix, _scanLexicon(memory, kSeasonLexicon).take(1));
  addPrefixed(kTagWeatherPrefix, _scanLexicon(memory, kWeatherLexicon).take(2));

  if (extras.isEmpty) return memory;

  final visible = memory.entities.where((e) => !isInternalMemoryEntityTag(e) && !e.startsWith('tag:')).toList();
  return memory.copyWith(entities: [...visible, ...extras]);
}

/// 타임라인·검색 칩용 — 내부 tag:/rel:/event: 접두사·합성 라벨 제외.
List<String> displayEntitiesForMemory(Memory memory, {String localeCode = 'ko'}) {
  return displayTagsForMemory(memory, localeCode: localeCode);
}
