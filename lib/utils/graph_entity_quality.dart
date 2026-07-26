import 'entity_canonical.dart';
import 'korean_person_names.dart';
import 'medical_entity_lexicon.dart';

/// 관계망 엔티티 품질 — 1·2단계 정규화 (조사·호칭·복합명사·별칭·부정문).

/// 분리하지 않을 복합 기관·장소 명사 (긴 순서 우선 매칭).
const List<String> kProtectedCompoundNouns = [
  '국민건강보험공단',
  '한국전자통신연구원',
  '서울대학교병원',
  '연세대학교병원',
  '삼성서울병원',
  '서울아산병원',
  '세브란스병원',
  '서울대학교',
  '연세대학교',
  '고려대학교',
  'KAIST',
  '삼성전자',
  'LG전자',
  'SK하이닉스',
  '국회의사당',
  '인천국제공항',
  '인천공항',
];

/// 인명 뒤·앞 직함·호칭 (제거 후 canonical 인명).
const List<String> kPersonTitleSuffixes = [
  '교수', '대표', '회장', '부회장', '사장', '부사장', '이사', '상무', '전무',
  '부장', '차장', '과장', '팀장', '실장', '원장', '소장', '국장', '처장',
  'CEO', 'CTO', 'CFO', 'COO', '박사', '선생', '선생님',
];

const Set<String> kKnownOrganizations = {
  '삼성전자', '삼성', '네이버', '카카오', 'LG', 'SK', '현대', '애플', '구글', '마이크로소프트',
  'OpenAI', '오픈AI', '환경부', '국세청', '대법원', '기획재정부', '외교부',
  '서울대학교', '연세대학교', '고려대학교', 'KAIST', 'POSTECH',
  '서울아산병원', '세브란스병원', '삼성서울병원', '서울대학교병원',
};

const Set<String> kMajorCities = {
  '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
  '수원', '창원', '고양', '용인', '성남', '청주', '전주', '천안',
};

const Set<String> kMajorCountries = {
  '대한민국', '한국', '일본', '미국', '중국', '영국', '프랑스', '독일',
};

/// 띄어쓰기 변형 통합.
const Map<String, String> kSpacingCanonical = {
  '서울 대학교': '서울대학교',
  '연세 대학교': '연세대학교',
  '고려 대학교': '고려대학교',
  '서울 아산병원': '서울아산병원',
};

/// 약어 추가 매핑 (alias 그룹에 없는 단축형).
const Map<String, String> kAbbreviationCanonical = {
  'ai': 'AI',
  'nlp': 'NLP',
  'llm': 'LLM',
  'gpu': 'GPU',
};

/// 그래프용 라벨 정규화 — 공백·오타·별칭·약어.
String normalizeGraphEntityLabel(String raw, {String localeCode = 'ko'}) {
  var label = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (label.isEmpty) return label;

  label = label.replaceAll(RegExp(r'[.,!?…·]+$'), '');
  label = kSpacingCanonical[label] ?? label;

  final abbrKey = label.toLowerCase();
  if (kAbbreviationCanonical.containsKey(abbrKey)) {
    label = kAbbreviationCanonical[abbrKey]!;
  }

  label = canonicalEntityLabel(label, localeCode: localeCode);
  return label;
}

/// 본문에서 보호 복합명사·알려진 기관·도시·국가 추출.
List<String> extractQualityOrganizations(String text, {String localeCode = 'ko'}) {
  final value = text.trim();
  if (value.isEmpty) return [];

  final found = <String>[];
  final seen = <String>{};

  void add(String label) {
    final norm = normalizeGraphEntityLabel(label, localeCode: localeCode);
    if (norm.isEmpty || !seen.add(norm)) return;
    // 「병원직원」처럼 역할 합성은 조직으로 쓰지 않음.
    if (norm.contains('직원') || norm.endsWith('들')) return;
    found.add(norm);
  }

  final sorted = [...kProtectedCompoundNouns, ...kKnownOrganizations]
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final compound in sorted) {
    if (value.contains(compound)) add(compound);
  }

  for (final match in RegExp(
    r'([가-힣A-Za-z0-9]{2,16}(?:전자|그룹|은행|증권|병원|대학교|학교|공단|연구원|재단))',
  ).allMatches(value)) {
    add(match.group(1)!);
  }

  for (final match in RegExp(r'([가-힣]{2,8}(?:부|청|원|위원회|공사))').allMatches(value)) {
    final token = match.group(1)!;
    if (token.length >= 3) add(token);
  }

  // 병원 회식 등 — 단독 병원·간호과 토큰 유지 (HEAD 호환).
  if (RegExp(r'병원').hasMatch(value) && !found.any((o) => o == '병원' || o.endsWith('병원'))) {
    add(localeCode == 'ko' ? '병원' : 'Hospital');
  }
  if (RegExp(r'간호과').hasMatch(value)) {
    add(localeCode == 'ko' ? '간호과' : 'Nursing dept');
  }
  if (RegExp(r'보호사(?:로는|들은|들|와|과)?').hasMatch(value)) {
    add(localeCode == 'ko' ? '보호사' : 'Care workers');
  }

  return found;
}

List<String> extractQualityPlaces(String text, {String localeCode = 'ko'}) {
  final value = text.trim();
  if (value.isEmpty) return [];

  final found = <String>[];
  final seen = <String>{};

  void add(String label) {
    final norm = normalizeGraphEntityLabel(label, localeCode: localeCode);
    if (norm.isEmpty || !seen.add(norm)) return;
    found.add(norm);
  }

  for (final compound in kProtectedCompoundNouns) {
    if (compound.contains('병원') || compound.contains('공항') || compound.contains('의사당')) {
      if (value.contains(compound)) add(compound);
    }
  }

  for (final match in RegExp(r'([가-힣A-Za-z0-9]{2,24}(?:병원|의원|클리닉))').allMatches(value)) {
    final token = match.group(1)!;
    if (!isMedicalGraphNoisePhrase(token)) add(token);
  }

  for (final city in kMajorCities) {
    if (RegExp('${RegExp.escape(city)}(?:에서|에|으로|까지|부터|시)?(?=[\\s,.]|\\\$)').hasMatch(value) ||
        value.contains('$city에서') ||
        value.contains('$city에')) {
      add(city);
    }
  }

  for (final country in kMajorCountries) {
    if (value.contains(country)) add(country);
  }

  for (final match in RegExp(r'([가-힣]{2,8}(?:구|시|군|도))').allMatches(value)) {
    final token = match.group(1)!;
    if (token.length >= 3 && !isLikelyKoreanPersonName(token)) add(token);
  }

  for (final match in RegExp(r'([가-힣]{2,12}(?:역|공항|의사당|타워|센터|빌딩))').allMatches(value)) {
    add(match.group(1)!);
  }

  return found;
}

/// 부정문 맥락 — 키워드 직후 「하지 않」「못」 등.
bool isNegatedRelationContext(String text, String keyword, {int lookahead = 14}) {
  final idx = text.indexOf(keyword);
  if (idx < 0) return false;
  final end = (idx + keyword.length + lookahead).clamp(0, text.length);
  final snippet = text.substring(idx, end);
  return RegExp(r'(?:않|못|없)(?:었|았|는|다|음|어|지)?|지\s?않|지\s?못|안\s').hasMatch(snippet);
}

/// 본문에서 엔티티 언급 횟수 (관계 강도 힌트).
int mentionCountInText(String entity, String text) {
  final needle = entity.trim();
  if (needle.isEmpty || text.isEmpty) return 0;
  return needle.allMatches(text).length;
}

/// 활동·관계 동사 어미 정규화 (하다 계열).
String normalizeActivityStem(String raw) {
  var v = raw.trim();
  if (v.isEmpty) return v;
  v = v.replaceAll(RegExp(r'(?:했|하였|했었|하고|하며|하면|하는|합니다|했다|하였다)$'), '');
  if (v.endsWith('하')) v = '${v}다';
  return v;
}
