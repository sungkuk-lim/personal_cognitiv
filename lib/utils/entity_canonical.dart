/// 엔티티 별칭 — 어머니=엄마=엄니 등 하나의 canonical 라벨로 통합.
const List<List<String>> kEntityAliasGroups = [
  ['어머니', '엄마', '엄니', 'mother', 'mom'],
  ['아버지', '아빠', 'father', 'dad'],
  ['집사람', '아내', '와이프', 'wife'],
  ['남편', '신랑', 'husband'],
  ['할아버지', '할배', 'grandfather'],
  ['할머니', 'grandmother'],
  ['할머니', '할무니'],
  ['AI', '인공지능', 'artificial intelligence'],
  ['OpenAI', '오픈AI', '오픈에이아이'],
  ['서울대학교', '서울 대학교'],
  ['연세대학교', '연세 대학교'],
  ['서울아산병원', '서울 아산병원'],
  ['삼성전자', '삼성 전자'],
  ['NLP', '자연어처리'],
  ['LLM', '거대언어모델'],
  ['GPU', '그래픽카드'],
];

final Map<String, String> _aliasToCanonical = () {
  final map = <String, String>{};
  for (final group in kEntityAliasGroups) {
    if (group.isEmpty) continue;
    final canonical = group.first;
    for (final alias in group) {
      map[alias.trim().toLowerCase()] = canonical;
    }
  }
  return map;
}();

String canonicalEntityLabel(String raw, {String localeCode = 'ko'}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final key = trimmed.toLowerCase();
  return _aliasToCanonical[key] ?? trimmed;
}

List<String> canonicalizeEntityList(Iterable<String> labels, {String localeCode = 'ko'}) {
  final seen = <String>{};
  final out = <String>[];
  for (final label in labels) {
    final c = canonicalEntityLabel(label, localeCode: localeCode);
    if (c.isEmpty || !seen.add(c)) continue;
    out.add(c);
  }
  return out;
}
