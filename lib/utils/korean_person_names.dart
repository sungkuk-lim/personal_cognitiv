import 'ocr_utils.dart';

/// 인물 이름으로 쓰이기 어려운 한국어 토큰 (동사·부사·일반명사).
const koreanPersonNameStopWords = {
  '오늘', '어제', '내일', '여기', '거기', '저기', '우리', '나는', '너는', '그는', '그녀',
  '바람', '날씨', '정말', '너무', '많이', '조금', '아주', '되게', '진짜',
  '놀러', '왔다', '갔다', '만났', '먹었', '했던', '이번', '다음', '그냥', '시원',
  '놀러왔다', '너무시원해', '너무시원', '기분', '느낌', '생각', '이야기', '말했',
  '월영', '안동', '경주', '서울', '부산', '대구', '인천', '광주', '대전', '울산',
  '연락', '다음날', '아직도', '아직', '혼자', '집으로', '그날', '여행', '추억',
  '장어', '조개', '술', '밤', '시쯤', '행동', '의문', '짐작', '이상', '실망',
  '남긴다', '모른다', '짐작만', '혼자사', '장어구', '조개구', '식구들', '이렇게',
};

/// 가족·친척 호칭 — 인명 규칙과 별도로 관계망 인물로 인정.
const koreanFamilyRelationTerms = {
  '아버지', '어머니', '집사람', '할아버지', '할머니', '아빠', '엄마',
  '남편', '아내', '형', '누나', '오빠', '언니', '동생', '아들', '딸',
  '손자', '손녀', '삼촌', '이모', '고모', '외삼촌', '며느리', '사위',
};

bool isFamilyRelationTerm(String raw) {
  final name = stripTrailingKoreanParticles(raw.trim());
  return koreanFamilyRelationTerms.contains(name);
}

/// 조사·어미 꼬리(는, 을, …)를 벗겨 이름·호칭 후보를 정리합니다.
String stripTrailingKoreanParticles(String raw) {
  var name = raw.trim();
  if (name.isEmpty) return name;

  const particles = ['에서는', '에서', '에게', '한테', '으로', '로는', '에는'];
  for (final p in particles) {
    if (name.endsWith(p) && name.length > p.length + 1) {
      name = name.substring(0, name.length - p.length);
      break;
    }
  }

  const shortParticles = ['는', '은', '을', '를', '과', '와', '도', '만', '에'];
  for (final p in shortParticles) {
    if (name.endsWith(p) && name.length > p.length + 1) {
      name = name.substring(0, name.length - p.length);
      break;
    }
  }

  return name;
}

const _placeSuffixes = [
  '교', '댐', '산', '봉', '령', '고개', '강', '천', '호', '해변', '공원', '시장', '역', '터널',
  '로', '길', '동', '읍', '면', '시', '군', '해수욕장',
];

/// 장소·부사 등 — 인물·장소 후보에서 제외.
bool isNonPlaceGraphToken(String word) {
  const blocked = {'아직도', '아직', '이미', '벌써', '다음날', '그날', '연락', '혼자', '집으로'};
  if (blocked.contains(word)) return true;
  if (word.length <= 3 && word.endsWith('도') && !word.endsWith('시도')) return true;
  return false;
}

bool looksLikeKoreanPlaceName(String word) {
  if (isNonPlaceGraphToken(word)) return false;
  if (word.length > 20) return false;
  if (word.contains(' ') && word.split(' ').length > 3) return false;
  if (word.endsWith('리') && word.length >= 3) return true;
  // 짧은 2~3글자 + 호/교 등은 인명과 겹침 (대호·월영 등).
  if (word.length <= 3 && (word.endsWith('호') || word.endsWith('교'))) return false;
  return _placeSuffixes.any(word.endsWith);
}

bool looksLikeListedPersonToken(String word) {
  final normalized = normalizeKoreanPersonName(stripTrailingKoreanParticles(word));
  if (isFamilyRelationTerm(normalized)) return true;
  if (!isLikelyKoreanPersonName(normalized)) return false;
  const blockedSuffixes = ['구이', '술', '밤', '일', '명'];
  if (blockedSuffixes.any(word.endsWith)) return false;
  if (word.endsWith('구') && word.length == 3) return false;
  if (RegExp(r'(?:한다|했다|긴다|는다|겠다|싶다)$').hasMatch(word)) return false;
  return true;
}

/// 2~4글자 한글 이름 후보인지 검사합니다.
bool isLikelyKoreanPersonName(String raw) {
  final name = normalizeKoreanPersonName(stripTrailingKoreanParticles(raw));
  if (isFamilyRelationTerm(name)) return true;
  if (name.length < 2 || name.length > 4) return false;
  if (!RegExp(r'^[가-힣]+$').hasMatch(name)) return false;
  if (koreanPersonNameStopWords.contains(name)) return false;
  if (RegExp(r'(?:한다|했다|긴다|는다|겠다|싶다)$').hasMatch(name)) return false;
  if (looksLikeKoreanPlaceName(name)) {
    if (name.length <= 3 && (name.endsWith('호') || name.endsWith('교'))) {
      // 인명과 겹치는 짧은 장소 접미사(대호·월영 등)는 인명 우선.
    } else {
      return false;
    }
  }
  if (isJunkEntityOrKeyword(name)) return false;
  return true;
}

String normalizeKoreanPersonName(String raw) {
  var name = stripTrailingKoreanParticles(raw.trim());
  if (isFamilyRelationTerm(name)) return name;
  if (name.length >= 3 && (name.endsWith('이') || name.endsWith('가'))) {
    final stem = name.substring(0, name.length - 1);
    if (stem.length >= 2 && !looksLikeKoreanPlaceName(stem)) {
      name = stem;
    }
  }
  return name;
}

/// 쉼표로 나열된 이름 (예: 해순, 은정, 연숙, 재운, 대호).
List<String> extractCommaListedKoreanNames(String text) {
  final names = <String>[];
  final seen = <String>{};

  void add(String? raw) {
    final name = normalizeKoreanPersonName(stripTrailingKoreanParticles(raw?.trim() ?? ''));
    if (name == '나') {
      if (seen.add('나')) names.add('나');
      return;
    }
    if (isFamilyRelationTerm(name)) {
      if (seen.add(name)) names.add(name);
      return;
    }
    if (!isLikelyKoreanPersonName(name)) return;
    if (seen.add(name)) names.add(name);
  }

  for (final match in RegExp(r'([가-힣]{2,4}(?:\s*,\s*[가-힣]{2,4}){1,7})').allMatches(text)) {
    final parts = match.group(1)!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) continue;
    var validCount = 0;
    for (final part in parts) {
      final normalized = normalizeKoreanPersonName(stripTrailingKoreanParticles(part));
      if (normalized == '나') {
        validCount++;
        continue;
      }
      if (isFamilyRelationTerm(normalized) || looksLikeListedPersonToken(part)) {
        validCount++;
      }
    }
    if (validCount < 2) continue;
    for (final part in parts) {
      if (part.trim() == '나') {
        add('나');
        continue;
      }
      add(part);
    }
  }

  // 날짜 뒤 이름 나열 (6월 18일 해순, 은정, … / 2026년 6월 22일 …).
  for (final pattern in [
    RegExp(r'\d{1,2}월\s*\d{1,2}일\s+([가-힣]{2,4}(?:\s*,\s*[가-힣]{2,4})+)'),
    RegExp(r'\d{4}년\s*\d{1,2}월\s*\d{1,2}일\s+([가-힣]{2,4}(?:\s*,\s*[가-힣]{2,4})+)'),
  ]) {
    final datedMatch = pattern.firstMatch(text);
    if (datedMatch == null) continue;
    for (final part in datedMatch.group(1)!.split(',')) {
      if (part.trim() == '나') {
        add('나');
        continue;
      }
      add(part);
    }
  }

  return names;
}

/// 사건·갈등에 더 많이 등장하는 인물을 앞에 둡니다.
List<String> rankPeopleForGraph(String content, List<String> names) {
  int score(String name) {
    var s = 0;
    if (RegExp('$name(?:이|가|와|랑|과|의|님|씨)').hasMatch(content)) s += 4;
    if (content.contains('$name랑') || content.contains('$name와') || content.contains('$name과')) {
      s += 8;
    }
    if (RegExp(r'(?:없어|사라|실종|이상|문제|갈등)').hasMatch(content) &&
        RegExp('$name(?:이|가)').hasMatch(content)) {
      s += 12;
    }
    return s;
  }

  final ranked = [...names]..sort((a, b) => score(b).compareTo(score(a)));
  return ranked;
}

List<String> filterLikelyPersonEntities(Iterable<String> entities) {
  return entities
      .map((e) => normalizeKoreanPersonName(e))
      .where(isLikelyKoreanPersonName)
      .toList();
}
