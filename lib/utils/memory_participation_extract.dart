import 'korean_person_names.dart';
import 'memory_entity_extract.dart';

/// 관계망에서 1인칭(앱 사용자) 노드 라벨.
String selfPersonGraphLabel(String localeCode) =>
    localeCode == 'ko' ? '나' : 'Me';

bool isSelfPersonToken(String token, String localeCode) {
  final t = token.trim();
  if (localeCode == 'ko') return t == '나' || t == '저' || t == '내';
  return RegExp(r'^I$|^me$|^myself$', caseSensitive: false).hasMatch(t);
}

bool isSelfPersonLabel(String label, String localeCode) =>
    label == selfPersonGraphLabel(localeCode);

/// 문장에서 「주어…는 [활동]을/를 …」 패턴으로 사람–활동 참여 관계 추출.
List<({String person, String activity})> extractParticipationLinks(
  String content, {
  required String localeCode,
  required Set<String> knownActivities,
}) {
  if (content.trim().isEmpty || knownActivities.isEmpty) return const [];

  final links = <({String person, String activity})>[];
  final seen = <String>{};

  for (final match in RegExp(r'([^.!?\n]{2,72}?)는\s+([^,.]{0,80}?)(?:을|를)').allMatches(content)) {
    final subjectsRaw = match.group(1)!.trim();
    final verbPhrase = match.group(2)!;
    if (subjectsRaw.length > 64) continue;

    final activity = _resolveActivityLabel(verbPhrase, knownActivities);
    if (activity == null) continue;

    for (final person in _parseSubjectTokens(subjectsRaw, localeCode)) {
      final key = '$person::$activity';
      if (seen.add(key)) {
        links.add((person: person, activity: activity));
      }
    }
  }

  return links;
}

String? _resolveActivityLabel(String verbPhrase, Set<String> knownActivities) {
  if (RegExp(r'고스톰|고스돔|고도리|고스톱').hasMatch(verbPhrase)) {
    if (knownActivities.contains('고스톰')) return '고스톰';
  }
  if (verbPhrase.contains('다슬기')) {
    if (knownActivities.contains('다슬기 잡기')) return '다슬기 잡기';
    if (knownActivities.contains('다슬기')) return '다슬기';
  }
  for (final activity in knownActivities) {
    if (verbPhrase.contains(activity)) return activity;
  }
  return null;
}

List<String> _parseSubjectTokens(String raw, String localeCode) {
  final self = selfPersonGraphLabel(localeCode);
  final out = <String>[];
  final seen = <String>{};

  void addPerson(String token) {
    var t = stripTrailingKoreanParticles(token.trim());
    if (t.isEmpty || t == '이렇게' || t == '식구' || t == '식구들') return;
    if (RegExp(r'^\d+명').hasMatch(t)) return;

    if (isSelfPersonToken(t, localeCode)) {
      if (seen.add(self)) out.add(self);
      return;
    }

    t = normalizeKoreanPersonName(t);
    if (isFamilyRelationTerm(t) || isLikelyKoreanPersonName(t)) {
      if (!isBlockedPersonName(t) && seen.add(t)) out.add(t);
    }
  }

  var phrase = raw;
  for (final split in ['고 ', '였고 ', '었고 ']) {
    final idx = phrase.lastIndexOf(split);
    if (idx >= 0 && idx < phrase.length - split.length) {
      phrase = phrase.substring(idx + split.length);
    }
  }

  for (final segment in phrase.split(RegExp(r'[,，]'))) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) continue;
    for (final part in trimmed.split(RegExp(r'(?:와|과|랑|이랑)(?=\s|$)'))) {
      addPerson(part);
    }
  }

  return out;
}
