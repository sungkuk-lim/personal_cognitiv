import 'package:flutter/material.dart';

import '../models/memory.dart';

String? formatMemoryLatLng(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

bool isLatLngLabel(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  return RegExp(r'^-?\d{1,3}\.\d{3,},\s*-?\d{1,3}\.\d{3,}$').hasMatch(value);
}

String preferLatLngTitle(Memory memory, String originalTitle) {
  final coords = formatMemoryLatLng(memory.lat, memory.lng);
  if (coords == null) return originalTitle;
  final title = originalTitle.trim();
  if (title.isEmpty) return coords;
  final parts = title.split('·').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return coords;
  if (isLatLngLabel(parts.first)) return originalTitle;
  return ([coords, ...parts.skip(1)]).join(' · ');
}

bool isGraphJunkTitle(String text) {
  final value = text.trim();
  if (value.isEmpty) return true;
  if (isJunkEntityOrKeyword(value) || isJunkOcrMetaResponse(value)) return true;

  final lower = value.toLowerCase();
  const uiJunkExact = ['제목', 'title', 'click', 'memory', '기억', 'placeholder'];
  if (uiJunkExact.contains(value) || uiJunkExact.contains(lower)) return true;

  const uiJunkContains = [
    '클릭하면',
    '클릭 시',
    '누르면',
    '선택하면',
    '탭하면',
    'tap to',
    'tap here',
  ];
  for (final phrase in uiJunkContains) {
    if (value.contains(phrase) || lower.contains(phrase)) return true;
  }

  if (isGraphMetaContent(value)) return true;
  return false;
}

/// 타임라인 메모용 머리말 — 관계망 핵심 의미 제목에서 제외합니다.
bool isGraphMetaContent(String text) {
  final value = text.trim();
  if (value.isEmpty) return true;

  const metaPhrases = [
    '오늘 있었던 일',
    '오늘 있었던일',
    '오늘 한 일',
    '오늘의 일',
    '오늘 일어난 일',
    '오늘 기록',
    '일기',
    '메모',
    'today',
    'daily log',
  ];
  final normalized = value.replaceAll(RegExp(r'[.!?…\s]+$'), '');
  for (final phrase in metaPhrases) {
    if (normalized == phrase || normalized.startsWith('$phrase ')) return true;
  }
  return false;
}

String sanitizeGraphNodeTitle(String raw) {
  final value = raw.trim();
  if (value.isEmpty || isGraphJunkTitle(value)) return '';
  return value;
}

bool isJunkEntityOrKeyword(String text) {
  final value = text.trim();
  if (value.isEmpty) return true;
  if (value.length > 28) return true;

  final lower = value.toLowerCase();
  const junkPhrases = [
    '추출할 수 없',
    '확인할 수 없',
    '볼 수 없',
    '읽을 수 없',
    '찾지 못',
    '글자를 찾',
    '이미지를',
    '사진을',
    '사진 속',
    '이미지 속',
    'ocr',
    'cannot extract',
    'cannot see',
    'cannot read',
    'cannot verify',
    'unable to',
    'no text found',
    'no visible text',
    '상황을 묘사',
    '메모리입니다',
    '메모리에',
    '기기에 저장된 사진',
    'photo on device',
    '기기',
    '사진',
    '저장됨',
    '저장된',
  ];
  for (final phrase in junkPhrases) {
    if (value.contains(phrase) || lower.contains(phrase)) return true;
  }
  return false;
}

/// 번지/지번 형태(예: 33-21, 101-3-12)는 관계망 엔티티에서 제외합니다.
bool isLikelyLotNumber(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  return RegExp(r'^\d{1,5}(?:-\d{1,5})+$').hasMatch(value);
}

bool isJunkOcrMetaResponse(String text) {
  final value = text.trim();
  if (value.isEmpty) return true;

  final lower = value.toLowerCase();
  const metaPhrases = [
    '글자를 찾지 못',
    '글자가 없',
    '글자가 보이지 않',
    '텍스트를 찾지 못',
    '텍스트가 없',
    '텍스트가 보이지 않',
    '사진에서 글자',
    '이미지에서 글자',
    '추출할 수 없',
    '확인할 수 없',
    'no text found',
    'no visible text',
    'cannot extract',
    'cannot read the text',
    'unable to extract',
    'unable to read',
    'i cannot see any text',
    "i can't see any text",
  ];
  for (final phrase in metaPhrases) {
    if (value.contains(phrase) || lower.contains(phrase)) return true;
  }
  return false;
}

/// 그래프·타임라인에 노출하지 않는 내부 태그 (rel:, event:, tag: 등).
bool isInternalMemoryEntityTag(String entity) {
  final e = entity.trim();
  return e.startsWith('tag:') ||
      e.startsWith('rel:') ||
      e.startsWith('event:') ||
      e.startsWith('time:') ||
      e.startsWith('importance:');
}

List<String> sanitizeEntities(List<String> entities) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in entities) {
    final entity = raw.trim();
    if (entity.isEmpty || isInternalMemoryEntityTag(entity)) continue;
    if (isJunkEntityOrKeyword(entity)) continue;
    if (seen.add(entity)) result.add(entity);
    if (result.length >= 6) break;
  }
  return result;
}

String graphTitleForMemory(Memory memory) {
  final summary = memory.summary.trim();
  if (summary.isNotEmpty && !isJunkEntityOrKeyword(summary)) return summary;

  final subCategory = memory.subCategory.trim();
  if (subCategory.isNotEmpty && !isJunkEntityOrKeyword(subCategory)) return subCategory;

  final content = memory.content.trim();
  if (content.isNotEmpty) {
    return content.length > 48 ? '${content.substring(0, 45)}...' : content;
  }
  return summary.isNotEmpty ? summary : 'Memory';
}

List<String> extractKeywordsFromText(String text) {
  final value = text.trim();
  if (value.isEmpty) return [];

  const stopWords = {
    '그리고', '하지만', '그래서', '에서', '으로', '에게', '까지', '부터', '이것', '저것', '그것',
    '있습니다', '합니다', '했습니다', '입니다', '오늘', '어제', '내일', '지금', '무엇', '어떤',
    '기기', '사진', '저장', '저장됨', '저장된', 'device', 'photo', 'stored', 'image',
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'have', 'has', 'was', 'were',
  };

  final tokens = <String>[];
  for (final match in RegExp(r'[가-힣]{2,}').allMatches(value)) {
    final raw = match.group(0)!;
    final word = _normalizeKoreanToken(raw);
    if (word.length < 2) continue;
    if (!stopWords.contains(word) && !isJunkEntityOrKeyword(word)) {
      tokens.add(word);
    }
  }
  for (final match in RegExp(r'[a-zA-Z]{3,}').allMatches(value.toLowerCase())) {
    final word = match.group(0)!;
    if (!stopWords.contains(word)) tokens.add(word);
  }
  return sanitizeEntities(tokens);
}

String _normalizeKoreanToken(String word) {
  var value = word;
  const suffixes = ['에서', '으로', '에게', '까지', '부터', '이라', '와', '과', '을', '를', '이', '가', '은', '는', '의', '에', '도', '만', '했다', '합니다', '입니다'];
  for (final suffix in suffixes) {
    if (value.endsWith(suffix) && value.length > suffix.length + 1) {
      value = value.substring(0, value.length - suffix.length);
      break;
    }
  }
  return value;
}

Set<String> contentTokensForMemory(Memory memory) {
  return extractKeywordsFromText('${memory.summary} ${memory.content} ${memory.subCategory}').toSet();
}

int sharedContentTokenCount(Memory a, Memory b) {
  return contentTokensForMemory(a).intersection(contentTokensForMemory(b)).length;
}

List<String> graphKeywordsForMemory(Memory memory) {
  final entities = sanitizeEntities(memory.entities)
      .where((e) => !isLatLngLabel(e))
      .toList();
  if (entities.isNotEmpty) return entities;

  final subCategory = memory.subCategory.trim();
  if (subCategory.isNotEmpty && !isJunkEntityOrKeyword(subCategory)) {
    return [subCategory];
  }

  return extractKeywordsFromText('${memory.summary} ${memory.content}');
}

String localizedCategoryLabel(Map<String, String> t, String category) {
  return t['cat_$category'] ?? category;
}

String languageNameForLocale(Locale locale) {
  switch (locale.languageCode) {
    case 'ko':
      return 'Korean';
    case 'en':
      return 'English';
    default:
      return 'the same language as the user input';
  }
}
