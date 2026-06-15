import 'package:flutter/material.dart';

import '../models/memory.dart';

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
  ];
  for (final phrase in junkPhrases) {
    if (value.contains(phrase) || lower.contains(phrase)) return true;
  }
  return false;
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

List<String> sanitizeEntities(List<String> entities) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in entities) {
    final entity = raw.trim();
    if (entity.isEmpty || isJunkEntityOrKeyword(entity)) continue;
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

List<String> graphKeywordsForMemory(Memory memory) {
  final entities = sanitizeEntities(memory.entities);
  if (entities.isNotEmpty) return entities;

  final subCategory = memory.subCategory.trim();
  if (subCategory.isNotEmpty && !isJunkEntityOrKeyword(subCategory)) {
    return [subCategory];
  }
  return [];
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
