import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/memory.dart';
import 'entity_canonical.dart';
import 'korean_person_names.dart';
import 'memory_entity_edit.dart';
import 'memory_entity_extract.dart';
import 'memory_entity_cache.dart';
import 'memory_participation_extract.dart';
import 'medical_entity_lexicon.dart';
import 'ocr_utils.dart';
import 'photo_memory_format.dart';

enum MemoryKeywordKind { person, pet, place, event, interest, activity, food, organization, tag }

MemoryKeywordKind classifyKeyword(String keyword, Memory memory, {String localeCode = 'ko'}) {
  final k = keyword.trim();
  if (k.isEmpty) return MemoryKeywordKind.tag;
  if (isMedicalGraphNoisePhrase(k)) return MemoryKeywordKind.tag;

  final bundle = MemoryEntityCache.bundle(memory, localeCode: localeCode);
  bool matches(String label) => entityLabelMatchesKeyword(label, k);

  // 0) 의료 시설·진료과 — 장소(물리적 위치)로 우선.
  if (isMedicalPlaceLikeLabel(k)) return MemoryKeywordKind.place;
  if (bundle.places.any(matches) && isMedicalPlaceLikeLabel(k)) return MemoryKeywordKind.place;
  for (final place in bundle.places) {
    if (matches(place) && (isMedicalPlaceLikeLabel(place) || isMedicalFacilityLabel(place))) {
      return MemoryKeywordKind.place;
    }
  }
  for (final org in bundle.organizations) {
    if (matches(org) && isMedicalFacilityLabel(org)) return MemoryKeywordKind.place;
  }

  // 1) 번들에 이미 분류된 항목 우선 (가장 신뢰도 높음).
  // 인명·호칭은 장소 번들보다 먼저 — 「정준호」가 places에 섞여도 사람으로.
  if (isSelfPersonLabel(k, localeCode) ||
      bundle.people.any(matches) ||
      isFamilyRelationTerm(k) ||
      looksLikePersonNameEndingInDong(k) ||
      looksLikePersonNameEndingInHo(k) ||
      (isLikelyKoreanPersonName(k) && !isGraphVenueToken(k) && !isMedicalPlaceLikeLabel(k))) {
    return MemoryKeywordKind.person;
  }
  if (bundle.pets.any(matches) ||
      isLikelyPetNameInContext(k, '${memory.summary}\n${memory.content}')) {
    return MemoryKeywordKind.pet;
  }
  if (bundle.places.any(matches) && !isPersonLabelNotPlace(k)) {
    return MemoryKeywordKind.place;
  }
  if (bundle.organizations.any(matches)) return MemoryKeywordKind.organization;
  if (bundle.events.any(matches)) return MemoryKeywordKind.event;
  if (bundle.interests.any(matches)) return MemoryKeywordKind.interest;
  if (bundle.food.any(matches)) return MemoryKeywordKind.food;
  if (bundle.activities.any(matches) || bundle.hobbies.any(matches)) {
    return MemoryKeywordKind.activity;
  }

  // 2) 인물 패턴 — 장소·의료 토큰보다 뒤.
  if (isMedicalNonPersonToken(k)) {
    if (isMedicalPlaceLikeLabel(k)) return MemoryKeywordKind.place;
    return MemoryKeywordKind.tag;
  }
  if (isFamilyRelationTerm(k)) return MemoryKeywordKind.person;
  if (looksLikePersonNameEndingInDong(k) || looksLikePersonNameEndingInHo(k)) {
    return MemoryKeywordKind.person;
  }
  if (isLikelyKoreanPersonName(k) && !looksLikeKoreanPlaceName(k) && !isGraphVenueToken(k)) {
    return MemoryKeywordKind.person;
  }

  // 3) 장소 패턴 — 인물이 아닐 때만.
  if (looksLikeKoreanPlaceName(k) && !isLikelyKoreanPersonName(k) && !isPersonLabelNotPlace(k)) {
    return MemoryKeywordKind.place;
  }

  for (final entity in userVisibleEntityLabels(memory, localeCode: localeCode)) {
    if (!entityLabelMatchesKeyword(entity, k)) continue;
    if (isLikelyKoreanPersonName(entity) || isLikelyKoreanPersonName(k)) {
      return MemoryKeywordKind.person;
    }
    if (looksLikeKoreanPlaceName(entity) && !isLikelyKoreanPersonName(entity)) {
      return MemoryKeywordKind.place;
    }
  }

  for (final person in bundle.people) {
    if (entityLabelMatchesKeyword(person, k)) return MemoryKeywordKind.person;
  }
  for (final place in bundle.places) {
    if (entityLabelMatchesKeyword(place, k)) return MemoryKeywordKind.place;
  }

  const placeSuffixes = [
    '교', '댐', '산', '봉', '령', '고개', '강', '천', '호', '해변', '해수욕장', '공원', '시장', '역', '터널', '로', '길', '읍', '면', '시', '군', '구',
  ];
  // 「동」「호」는 인명(홍길동·정준호)과 겹치므로 인명 가드 후 장소로.
  if (placeSuffixes.any(k.endsWith) && !isPersonLabelNotPlace(k)) {
    return MemoryKeywordKind.place;
  }
  if (k.endsWith('동') && k.length >= 3 && !looksLikePersonNameEndingInDong(k)) {
    return MemoryKeywordKind.place;
  }

  if (keyword.length >= 2 &&
      keyword.length <= 4 &&
      RegExp(r'^[가-힣]+$').hasMatch(keyword)) {
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
    // 인명과 의료시설·진료과는 서로 매칭하지 않음 (정준호 ↔ 성소병원 오매칭 방지).
    if (isMedicalNonPersonToken(k) || isMedicalNonPersonToken(e) ||
        isMedicalPlaceLikeLabel(k) || isMedicalPlaceLikeLabel(e)) {
      return false;
    }
    return normalizeKoreanPersonName(e) == normalizeKoreanPersonName(k);
  }
  if (isMedicalPlaceLikeLabel(k) || isMedicalPlaceLikeLabel(e)) {
    return e.contains(k) || k.contains(e);
  }
  return false;
}

/// 검색·포커스 정렬용 — 높을수록 더 관련 있음.
int memoryKeywordMatchScore(Memory memory, String keyword, {String localeCode = 'ko'}) {
  final k = keyword.trim();
  if (k.isEmpty) return 0;

  for (final entity in sanitizeEntities(memory.entities)) {
    if (isInternalMemoryEntityTag(entity)) continue;
    if (isPersonPlaceCompositeActivity(entity)) continue;
    if (!memoryHasManualEntityEdit(memory) && !entityLabelReferencedInMemory(entity, memory)) continue;
    if (entityLabelMatchesKeyword(entity, k)) return 100;
  }

  final bundle = MemoryEntityCache.bundle(memory, localeCode: localeCode);
  for (final person in bundle.people) {
    if (isSelfPersonLabel(person, localeCode)) continue;
    if (entityLabelMatchesKeyword(person, k)) return 95;
  }
  for (final pet in bundle.pets) {
    if (entityLabelMatchesKeyword(pet, k)) return 93;
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
    case MemoryKeywordKind.pet:
      return Icons.pets_outlined;
    case MemoryKeywordKind.place:
      return Icons.place_outlined;
    case MemoryKeywordKind.event:
      return Icons.event_note_outlined;
    case MemoryKeywordKind.interest:
      return Icons.lightbulb_outline_rounded;
    case MemoryKeywordKind.activity:
      return Icons.directions_walk_outlined;
    case MemoryKeywordKind.food:
      return Icons.restaurant_outlined;
    case MemoryKeywordKind.organization:
      return Icons.business_outlined;
    case MemoryKeywordKind.tag:
      return Icons.sell_outlined;
  }
}

Color colorForKeywordKind(MemoryKeywordKind kind, ColorScheme scheme) {
  switch (kind) {
    case MemoryKeywordKind.person:
      return AppGraphColors.person;
    case MemoryKeywordKind.pet:
      return AppGraphColors.pet;
    case MemoryKeywordKind.place:
      return AppGraphColors.place;
    case MemoryKeywordKind.event:
      return AppGraphColors.event;
    case MemoryKeywordKind.interest:
      return AppGraphColors.interest;
    case MemoryKeywordKind.activity:
      return AppGraphColors.activity;
    case MemoryKeywordKind.food:
      return AppGraphColors.food;
    case MemoryKeywordKind.organization:
      return AppGraphColors.organization;
    case MemoryKeywordKind.tag:
      return scheme.primary;
  }
}

List<Widget> buildKeywordChips(
  Memory memory,
  ColorScheme colorScheme, {
  int maxCount = 6,
  void Function(String keyword)? onKeywordTap,
  String localeCode = 'ko',
}) {
  final keywords = displayTagsForMemory(memory, localeCode: localeCode).take(maxCount).toList();
  return buildKeywordChipsFromLabels(
    memory,
    keywords,
    colorScheme,
    onKeywordTap: onKeywordTap,
  );
}

List<Widget> buildKeywordChipsFromLabels(
  Memory memory,
  List<String> keywords,
  ColorScheme colorScheme, {
  void Function(String keyword)? onKeywordTap,
}) {
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
