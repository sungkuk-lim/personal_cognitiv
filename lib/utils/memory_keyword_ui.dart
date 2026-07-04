import 'package:flutter/material.dart';

import '../models/memory.dart';
import 'entity_canonical.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';
import 'memory_participation_extract.dart';
import 'ocr_utils.dart';
import 'photo_memory_format.dart';

enum MemoryKeywordKind { person, place, tag }

MemoryKeywordKind classifyKeyword(String keyword, Memory memory, {String localeCode = 'ko'}) {
  final k = keyword.trim();
  if (k.isEmpty) return MemoryKeywordKind.tag;

  if (looksLikeKoreanPlaceName(k)) return MemoryKeywordKind.place;

  for (final entity in userVisibleEntityLabels(memory)) {
    if (!entityLabelMatchesKeyword(entity, k)) continue;
    if (isLikelyKoreanPersonName(k) || isLikelyKoreanPersonName(entity)) {
      return MemoryKeywordKind.person;
    }
    if (looksLikeKoreanPlaceName(entity)) return MemoryKeywordKind.place;
  }

  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  for (final person in bundle.people) {
    if (entityLabelMatchesKeyword(person, k)) return MemoryKeywordKind.person;
  }
  for (final place in bundle.places) {
    if (entityLabelMatchesKeyword(place, k)) return MemoryKeywordKind.place;
  }

  const placeSuffixes = [
    '교', '댐', '산', '봉', '령', '고개', '강', '천', '호', '해변', '해수욕장', '공원', '시장', '역', '터널', '로', '길', '동', '읍', '면', '시', '군', '구',
  ];
  if (placeSuffixes.any(k.endsWith)) return MemoryKeywordKind.place;

  if (keyword.length >= 2 &&
      keyword.length <= 4 &&
      RegExp(r'^[가-힣]+$').hasMatch(keyword) &&
      !placeSuffixes.any(keyword.endsWith)) {
    if (memory.content.contains('$keyword이') ||
        memory.content.contains('$keyword와') ||
        memory.content.contains('$keyword과') ||
        memory.content.contains('$keyword님')) {
      return MemoryKeywordKind.person;
    }
  }

  final lower = k.toLowerCase();
  if (lower.contains('station') || lower.contains('park') || lower.contains('street')) {
    return MemoryKeywordKind.place;
  }

  return MemoryKeywordKind.tag;
}

/// 엔티티 라벨이 검색 키워드와 같은 대상인지 (조사·이름 변형 허용).
bool entityLabelMatchesKeyword(String entity, String keyword) {
  final e = stripTrailingKoreanParticles(entity.trim());
  final k = stripTrailingKoreanParticles(keyword.trim());
  if (e.isEmpty || k.isEmpty) return false;
  if (e == k) return true;
  if (isFamilyRelationTerm(k) || isFamilyRelationTerm(e)) {
    return canonicalEntityLabel(e) == canonicalEntityLabel(k);
  }
  if (isLikelyKoreanPersonName(k) || isLikelyKoreanPersonName(e)) {
    return normalizeKoreanPersonName(e) == normalizeKoreanPersonName(k);
  }
  if (looksLikeKoreanPlaceName(k) || looksLikeKoreanPlaceName(e)) {
    return e.contains(k) || k.contains(e);
  }
  return false;
}

/// 검색·포커스 정렬용 — 높을수록 더 관련 있음.
int memoryKeywordMatchScore(Memory memory, String keyword, {String localeCode = 'ko'}) {
  final k = keyword.trim();
  if (k.isEmpty) return 0;

  for (final entity in userVisibleEntityLabels(memory)) {
    if (entityLabelMatchesKeyword(entity, k)) return 100;
  }

  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  for (final person in bundle.people) {
    if (isSelfPersonLabel(person, localeCode)) continue;
    if (entityLabelMatchesKeyword(person, k)) return 95;
  }
  for (final place in bundle.places) {
    if (entityLabelMatchesKeyword(place, k)) return 90;
  }
  for (final activity in bundle.activities) {
    if (entityLabelMatchesKeyword(activity, k)) return 85;
  }
  if (bundle.eventTitle.trim().isNotEmpty && entityLabelMatchesKeyword(bundle.eventTitle, k)) {
    return 80;
  }

  if (isLikelyKoreanPersonName(k) || isFamilyRelationTerm(k)) {
    return _personMentionedInText('${memory.content}\n${memory.summary}', k) ? 70 : 0;
  }

  if (looksLikeKoreanPlaceName(k)) {
    final hint = extractPlaceHintFromOcr(memory.content);
    if (hint != null && entityLabelMatchesKeyword(hint, k)) return 65;
  }

  if (memory.content.contains(k)) return 50;
  if (memory.summary.contains(k)) return 40;
  final lower = k.toLowerCase();
  if (lower != k && memory.content.toLowerCase().contains(lower)) return 35;
  return 0;
}

/// 키워드와 연결된 기억인지 — 인물명은 엔티티·호칭 패턴으로만 매칭합니다.
bool memoryMatchesKeyword(Memory memory, String keyword, {String localeCode = 'ko'}) {
  return memoryKeywordMatchScore(memory, keyword, localeCode: localeCode) > 0;
}

bool _personMentionedInText(String text, String name) {
  if (text.isEmpty) return false;
  final escaped = RegExp.escape(name);
  final particle = RegExp('$escaped(이|가|은|는|과|와|님|을|를|에게|한테|께서|이랑|랑|하고|과는|와는|도|만)?(?![가-힣])');
  return particle.hasMatch(text) || text.contains(name);
}

IconData iconForKeywordKind(MemoryKeywordKind kind) {
  switch (kind) {
    case MemoryKeywordKind.person:
      return Icons.person_outline_rounded;
    case MemoryKeywordKind.place:
      return Icons.place_outlined;
    case MemoryKeywordKind.tag:
      return Icons.sell_outlined;
  }
}

Color colorForKeywordKind(MemoryKeywordKind kind, ColorScheme scheme) {
  switch (kind) {
    case MemoryKeywordKind.person:
      return Colors.pink.shade400;
    case MemoryKeywordKind.place:
      return Colors.teal.shade500;
    case MemoryKeywordKind.tag:
      return scheme.primary;
  }
}

List<Widget> buildKeywordChips(
  Memory memory,
  ColorScheme colorScheme, {
  int maxCount = 6,
  void Function(String keyword)? onKeywordTap,
}) {
  final keywords = userVisibleEntityLabels(memory).take(maxCount).toList();
  if (keywords.isEmpty) return const [];

  return keywords.map((keyword) {
    final kind = classifyKeyword(keyword, memory);
    final color = colorForKeywordKind(kind, colorScheme);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForKeywordKind(kind), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            keyword,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
    if (onKeywordTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onKeywordTap(keyword),
        borderRadius: BorderRadius.circular(20),
        child: chip,
      ),
    );
  }).toList();
}
