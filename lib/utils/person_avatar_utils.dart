import 'package:flutter/material.dart';

import 'entity_canonical.dart';
import 'korean_person_names.dart';

const List<Color> kPersonAvatarPalette = [
  Color(0xFFE91E63),
  Color(0xFF9C27B0),
  Color(0xFF3F51B5),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFFF57C00),
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFF8E24AA),
  Color(0xFFD81B60),
];

const Map<String, String> _parentRelationAlternates = {
  '엄마': '어머니',
  '어머니': '엄마',
  '아빠': '아버지',
  '아버지': '아빠',
  '엄니': '어머니',
};

String sanitizeContactLabel(String raw) {
  return raw
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .trim();
}

/// 연락처 사진 매칭용 — 복합 이름(예린엄마)은 그대로, 단독 호칭(엄마)만 canonical.
String contactPhotoLookupKey(String raw) {
  final display = normalizeContactDisplayName(sanitizeContactLabel(raw));
  final normalized = normalizeKoreanPersonName(stripTrailingKoreanParticles(display));
  final compact = normalized.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  if (compact.isEmpty) return compact;
  if (isFamilyRelationTerm(compact)) {
    return canonicalEntityLabel(compact).replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }
  return compact;
}

/// 그래프 엔티티 매칭용 (기존).
String contactLookupKey(String raw) {
  final display = normalizeContactDisplayName(sanitizeContactLabel(raw));
  final canonical = canonicalEntityLabel(display);
  final normalized = normalizeKoreanPersonName(stripTrailingKoreanParticles(canonical));
  return normalized.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

/// 연락처 표시 이름 정리 — 「예린 엄마」, 「엄마(예린)」 등을 통일합니다.
String normalizeContactDisplayName(String raw) {
  var text = sanitizeContactLabel(raw).replaceAll(RegExp(r'[·•]+'), ' ');
  if (text.isEmpty) return text;

  final paren = RegExp(r'^(.+?)[\(\（](.+?)[\)\）]$').firstMatch(text);
  if (paren != null) {
    final left = paren.group(1)!.trim();
    final right = paren.group(2)!.trim();
    if (isFamilyRelationTerm(left)) return '$right$left';
    if (isFamilyRelationTerm(right)) return '$left$right';
  }

  text = text.replaceAll(RegExp(r'[()[\]{}（）\[\]]'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _parentRelationSuffixes = [
  '엄마', '아빠', '어머니', '아버지', '할머니', '할아버지', '할배', '아버님', '어머님', '엄니',
];

void _addParentCompoundVariants(Set<String> rawNames, String compact) {
  for (final suffix in _parentRelationSuffixes) {
    if (!compact.endsWith(suffix) || compact.length <= suffix.length) continue;
    final prefix = compact.substring(0, compact.length - suffix.length);
    if (prefix.isEmpty) continue;
    rawNames.add('$prefix$suffix');
    rawNames.add('$prefix $suffix');
    final alt = _parentRelationAlternates[suffix];
    if (alt != null) {
      rawNames.add('$prefix$alt');
      rawNames.add('$prefix $alt');
    }
  }
}

/// 그래프·연락처 조회 시 시도할 키 목록.
List<String> contactLookupAliases(String raw) {
  final seen = <String>{};
  final keys = <String>[];

  void addRaw(String value) {
    final key = contactPhotoLookupKey(value);
    if (key.isNotEmpty && seen.add(key)) keys.add(key);
  }

  addRaw(raw);
  final normalized = normalizeContactDisplayName(raw);
  if (normalized != sanitizeContactLabel(raw)) addRaw(normalized);

  final rawNames = <String>{sanitizeContactLabel(raw), normalized};
  _addParentCompoundVariants(rawNames, contactPhotoLookupKey(raw));
  for (final name in rawNames) {
    addRaw(name);
  }

  return keys;
}

String personAvatarInitial(String raw) {
  final name = contactPhotoLookupKey(raw);
  if (name.isEmpty) return '?';
  return String.fromCharCode(name.runes.first).toUpperCase();
}

Color personAvatarColor(String raw) {
  final key = contactPhotoLookupKey(raw);
  var hash = 0;
  for (final code in key.runes) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return kPersonAvatarPalette[hash % kPersonAvatarPalette.length];
}

/// 연락처 한 명의 모든 이름 후보를 lookup 키로 펼칩니다.
List<String> contactIndexKeysForContact({
  required String displayName,
  String firstName = '',
  String lastName = '',
  String nickname = '',
  String middleName = '',
}) {
  final rawNames = <String>{
    displayName,
    normalizeContactDisplayName(displayName),
    firstName,
    lastName,
    nickname,
    middleName,
  };

  if (firstName.trim().isNotEmpty && lastName.trim().isNotEmpty) {
    final first = firstName.trim();
    final last = lastName.trim();
    rawNames.addAll([
      '$first$last',
      '$first $last',
      '$last$first',
      '$last $first',
    ]);
    final lastKey = contactPhotoLookupKey(last);
    for (final entry in _parentRelationAlternates.entries) {
      if (lastKey == contactPhotoLookupKey(entry.key)) {
        rawNames.add('$first${entry.value}');
        rawNames.add('$first ${entry.value}');
      }
    }
  }

  for (final name in rawNames.toList()) {
    if (name.trim().isEmpty) continue;
    _addParentCompoundVariants(rawNames, contactPhotoLookupKey(name));
  }

  final keys = <String>[];
  final seen = <String>{};
  for (final raw in rawNames) {
    if (raw.trim().isEmpty) continue;
    for (final alias in contactLookupAliases(raw)) {
      if (alias.isNotEmpty && seen.add(alias)) keys.add(alias);
    }
  }
  return keys;
}

/// 그래프 노드 이름과 연락처 표시 이름이 같은 사람인지 (느슨한 매칭).
bool contactNamesLikelyMatch(String contactName, String graphName) {
  return contactNameMatchScore(contactName, graphName) >= 6;
}

int contactNameMatchScore(String contactName, String graphName) {
  return contactNameMatchScoreForKeys(contactPhotoLookupKey(contactName), contactPhotoLookupKey(graphName));
}

int contactNameMatchScoreForKeys(String contactKey, String graphKey) {
  return _contactNameMatchScore(contactKey, graphKey);
}

int _contactNameMatchScore(String contactKey, String graphKey) {
  if (contactKey == graphKey) return 100;
  final parentVariant = _parentCompoundVariantScore(contactKey, graphKey);
  if (parentVariant > 0) return parentVariant;
  if (contactKey.contains(graphKey) || graphKey.contains(contactKey)) {
    final shorter = contactKey.length < graphKey.length ? contactKey : graphKey;
    if (shorter.length >= 2) return shorter.length + 4;
  }
  if (contactKey.endsWith(graphKey) || graphKey.endsWith(contactKey)) {
    final shorter = contactKey.length < graphKey.length ? contactKey : graphKey;
    if (shorter.length >= 2) return shorter.length + 3;
  }
  return 0;
}

int _parentCompoundVariantScore(String a, String b) {
  for (final suffix in _parentRelationSuffixes) {
    final alt = _parentRelationAlternates[suffix];
    if (alt == null) continue;
    if (a.endsWith(suffix) && a.length > suffix.length) {
      final prefix = a.substring(0, a.length - suffix.length);
      if (b == '$prefix$alt') return 100;
    }
    if (b.endsWith(suffix) && b.length > suffix.length) {
      final prefix = b.substring(0, b.length - suffix.length);
      if (a == '$prefix$alt') return 100;
    }
  }
  return 0;
}

/// 그래프 이름과 연락처 키 집합이 겹치는지.
bool contactKeysOverlap(Iterable<String> contactKeys, Iterable<String> graphKeys) {
  final graph = graphKeys.toSet();
  for (final key in contactKeys) {
    if (graph.contains(key)) return true;
  }
  return false;
}
