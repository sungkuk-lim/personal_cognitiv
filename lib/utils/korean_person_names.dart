import 'medical_entity_lexicon.dart';
import 'ocr_utils.dart';
import 'memory_semantic_extract.dart';

/// 인물 이름으로 쓰이기 어려운 한국어 토큰 (동사·부사·일반명사).
const koreanPersonNameStopWords = {
  '오늘', '어제', '내일', '여기', '거기', '저기', '우리', '나는', '너는', '그는', '그녀',
  '바람', '날씨', '정말', '너무', '많이', '조금', '아주', '되게', '진짜',
  '놀러', '왔다', '갔다', '만났', '먹었', '했던', '이번', '다음', '그냥', '시원',
  '놀러왔다', '너무시원해', '너무시원', '너무시', '기분', '느낌', '생각', '이야기', '말했',
  '월영', '안동', '경주', '서울', '부산', '대구', '인천', '광주', '대전', '울산',
  '연락', '다음날', '아직도', '아직', '혼자', '집으로', '그날', '여행', '추억', '기억',
  '장어', '조개', '술', '밤', '시쯤', '행동', '의문', '짐작', '이상', '실망',
  '남긴다', '모른다', '짐작만', '혼자사', '장어구', '조개구', '식구들', '식두들', '이렇게', '엉망',
  '둘', '셋', '넷', '그', '이', '저',
  '아이디어', '경험', '협력', '프로젝트', '논의', '중요성', '창의', '창의적',
  '인공지능', '스타트업',
  '시간', '후에', '처음', '대학생', '산책', '식사',
  '짬나', '짬', '근무', '수박', '전화', '통화', '문자',
  '노견', '암견', '수견', '첫째', '둘째', '셋째', '넷째', '막내',
  '안과', '치과', '정형외과', '정형외', '소화기내과', '소화기', '외진', '외진현황', '현황', '보고', '환자',
};

const Set<String> kKnownPetNames = {
  '마루', '두부', '만두', '초코', '보리', '몽이', '콩이', '코코',
};

const Set<String> kPetOrdinalPrefixes = {
  '첫째', '둘째', '셋째', '넷째', '막내',
};

const Set<String> kPetDescriptorTokens = {
  '노견', '암견', '수견', '강아지', '반려견', '반려동물', '애견', '댕댕이', '견주',
};

const Set<String> kPetContextKeywords = {
  '반려견', '반려묘', '강아지', '고양이', '냥이', '노견', '애견', '댕댕이', '반려동물', '견주', '묘주',
};

bool isPetOrdinalToken(String raw) {
  return kPetOrdinalPrefixes.contains(stripTrailingKoreanParticles(raw.trim()));
}

bool isPetDescriptorToken(String raw) {
  return kPetDescriptorTokens.contains(stripTrailingKoreanParticles(raw.trim()));
}

bool textHasPetNarrativeContext(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  if (kPetContextKeywords.any(value.contains)) return true;
  return RegExp(r'(?:입양|데려왔)').hasMatch(value);
}

bool mentionedAsPetInText(String token, String context) {
  final name = stripTrailingKoreanParticles(token.trim());
  if (name.length < 2) return false;
  final escaped = RegExp.escape(name);
  if (RegExp('$escaped(?:을|를)\\s*(?:입양|데려왔|안고)').hasMatch(context)) return true;
  if (RegExp('$escaped(?:은|는|이|가)\\s').hasMatch(context) && textHasPetNarrativeContext(context)) {
    return true;
  }
  if (RegExp('반려견\\s+$escaped').hasMatch(context)) return true;
  return false;
}

/// 대명사·지시어 + 조사 형태.
bool isKoreanPronounWithParticle(String raw) {
  final v = raw.trim();
  return RegExp(r'^(?:둘|셋|넷|그|이|저|우리|너희|그녀|그들)(?:은|는|이|가|을|를|과|와|도|만|한테|에게)?$').hasMatch(v);
}

/// 동사 활용·조사 찌꺼기 — 인물/장소 노드에서 제외.
bool isGraphMorphologyJunkToken(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return true;
  if (isKoreanPronounWithParticle(trimmed)) return true;
  final v = stripTrailingKoreanParticles(trimmed);
  if (v.isEmpty) return true;
  if (koreanPersonNameStopWords.contains(v)) return true;
  if (RegExp(r'^[을를이가은는]$').hasMatch(v)) return true;
  if (RegExp(r'^[을를이가]\s').hasMatch(v)) return true;
  if (RegExp(r'(?:았|었|였)(?:고|으며|서|니)?$').hasMatch(v)) return true;
  if (RegExp(r'(?:받았|했|됐|갔|왔|봤|먹었|만난|추천|가기|즐긴|했다)$').hasMatch(v)) return true;
  if (RegExp(r'(?:이고|이며|하고|으며|라고|다고|면서)$').hasMatch(v)) return true;
  if (v == '추천' || v.endsWith('추천')) return true;
  return false;
}

/// 「천」 접미가 실제 지명이 아닌 일반어(추천 등).
bool isMisleadingPlaceChonToken(String word) {
  final v = word.trim();
  if (v.isEmpty) return false;
  const blocked = {'추천', '만원', '백만', '천만', '오천', '이천'};
  if (blocked.contains(v)) return true;
  // 「부산 광안리 해수욕장」처럼 도시 불용어가 섞인 정상 지명은 유지.
  // 형태소 불용어는 「~천」 오탐(추천 등)에만 적용.
  if (v.endsWith('천') && isGraphMorphologyJunkToken(v)) return true;
  if (v.contains(' ') && v.split(RegExp(r'\s+')).any(isMisleadingPlaceChonToken)) {
    return true;
  }
  return false;
}

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

/// 「예린엄마」「태민아빠」「애들할머니」 등 아이·관계 접두 + 역할 접미 복합 호칭.
const kCompoundParentRoleSuffixes = [
  '엄마', '아빠', '할아버지', '할머니', '고모', '삼촌', '이모',
];

bool isCompoundParentTerm(String raw) {
  final t = stripTrailingKoreanParticles(raw.trim());
  if (t.isEmpty || koreanFamilyRelationTerms.contains(t)) return false;
  for (final suffix in kCompoundParentRoleSuffixes) {
    if (t.endsWith(suffix) && t.length > suffix.length) {
      final prefix = t.substring(0, t.length - suffix.length);
      if (RegExp(r'^[가-힣]{1,8}$').hasMatch(prefix)) return true;
    }
  }
  return false;
}

List<String> extractCompoundParentTermsFromText(String text) {
  final value = text.trim();
  if (value.isEmpty) return [];

  final found = <String>[];
  final seen = <String>{};
  final suffixPattern = kCompoundParentRoleSuffixes.map(RegExp.escape).join('|');
  final pattern = RegExp(
    '([가-힣]{1,8})($suffixPattern)(?:과|와|랑|이랑|을|를|의|에게|한테|님|씨|도|만|하고|이|가|은|는)?',
  );
  for (final match in pattern.allMatches(value)) {
    final label = '${match.group(1)}${match.group(2)}';
    if (seen.add(label)) found.add(label);
  }
  return found;
}

/// 가족 접미(엄마·아빠)가 복합 호칭 안에 묻혀 있는지 — 「예린엄마」 속 「엄마」 단독 추출 방지.
bool isFamilyTermEmbeddedInCompound(String text, String term) {
  if (!koreanFamilyRelationTerms.contains(term)) return false;
  if (term.length > 3) return false;
  return RegExp('[가-힣]{1,8}${RegExp.escape(term)}').hasMatch(text);
}

/// 「아들이」「엄마와」처럼 조사가 붙은 가족 호칭을 본문에서 찾습니다.
List<String> extractFamilyRelationTermsFromText(String text) {
  final value = text.trim();
  if (value.isEmpty) return [];

  final compounds = extractCompoundParentTermsFromText(value).toSet();
  final found = <String>[];
  final seen = <String>{};
  for (final term in koreanFamilyRelationTerms) {
    if (compounds.any((c) => c.endsWith(term) && c.length > term.length)) continue;
    if (isFamilyTermEmbeddedInCompound(value, term)) continue;
    final pattern = RegExp(
      '(?<![가-힣])${RegExp.escape(term)}(?:이|가|은|는|과|와|랑|이랑|을|를|의|에게|한테|님|씨|도|만|하고)?(?=[\\s,.!?]|\\\$)',
    );
    if (pattern.hasMatch(value) && seen.add(term)) {
      found.add(term);
    }
  }
  return found;
}

/// 조사·어미 꼬리(는, 을, …)를 벗겨 이름·호칭 후보를 정리합니다.
String stripTrailingKoreanParticles(String raw) {
  var name = raw.trim();
  if (name.isEmpty) return name;
  if (isMedicalDepartmentLabel(name)) return name.replaceAll(RegExp(r'[.,!?…·]+$'), '').trim();

  const particles = ['에서는', '에서', '에게', '한테', '으로', '로는', '에는'];
  for (final p in particles) {
    if (name.endsWith(p) && name.length > p.length + 1) {
      name = name.substring(0, name.length - p.length);
      break;
    }
  }

  const shortParticles = ['는', '은', '을', '를', '과', '와', '도', '만', '에'];
  for (final p in shortParticles) {
    if (!name.endsWith(p) || name.length <= p.length) continue;
    final stem = name.substring(0, name.length - p.length);
    if (p == '과' && isMedicalDepartmentLabel(name)) break;
    if (name.length > p.length + 1 || koreanPersonNameStopWords.contains(stem)) {
      name = stem;
      break;
    }
  }

  return name;
}

const _koreanSurnameChars = {
  '김', '이', '박', '최', '정', '강', '조', '윤', '장', '임', '한', '오', '서', '신',
  '권', '황', '안', '송', '류', '전', '홍', '문', '양', '손', '배', '백', '허', '유',
  '남', '심', '노', '하', '곽', '성', '차', '주', '우', '구', '민', '진', '지', '엄',
};

/// 「홍길동」처럼 동으로 끝나도 성+이름 3글자 인명.
bool looksLikePersonNameEndingInDong(String word) {
  if (word.length != 3 || !word.endsWith('동')) return false;
  return _koreanSurnameChars.contains(word[0]);
}

/// 「정준호」「김준호」처럼 호로 끝나도 성+이름 인명 (장소 접미사 호와 구분).
bool looksLikePersonNameEndingInHo(String word) {
  if (!word.endsWith('호')) return false;
  if (word.length < 3 || word.length > 4) return false;
  return _koreanSurnameChars.contains(word[0]);
}

/// 장소 후보에서 빼야 할 인명·호칭.
///
/// 2글자 휴리스틱은 「카페」 등을 인명으로 오인하므로 3~4글자(또는 호칭)만 대상.
bool isPersonLabelNotPlace(String raw) {
  final name = normalizeKoreanPersonName(stripTrailingKoreanParticles(raw));
  if (name.isEmpty) return false;
  if (isFamilyRelationTerm(name)) return true;
  // 월영교·길안천 등 장소 시설은 인명으로 보지 않음.
  if (looksLikeKoreanPlaceName(name)) return false;
  if (looksLikePersonNameEndingInDong(name) || looksLikePersonNameEndingInHo(name)) {
    return true;
  }
  if (name.length < 3 || name.length > 4) return false;
  return isLikelyKoreanPersonName(name);
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
  if (isMisleadingPlaceChonToken(word)) return false;
  if (word.length > 20) return false;
  if (word.contains(' ') && word.split(' ').length > 3) return false;
  if (word.endsWith('리') && word.length >= 3) return true;
  // 「너무시」처럼 형용사 조각 + 시 오탐 방지.
  if (word.endsWith('시')) {
    if (word.length < 3 || word == '시') return false;
    if (isGraphMorphologyJunkToken(word)) return false;
  }
  // 짧은 호는 인명과 겹침. 교·천·산·강은 장소 시설.
  if (word.length <= 3 && word.endsWith('호')) return false;
  // 성+동 인명(홍길동)은 장소로 보지 않음. 행정동은 추출 문맥에서 별도 허용.
  if (looksLikePersonNameEndingInHo(word) || looksLikePersonNameEndingInDong(word)) {
    return false;
  }
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
  if (isGraphMorphologyJunkToken(word)) return false;
  return true;
}

/// 2~4글자 한글 이름 후보인지 검사합니다.
bool isLikelyKoreanPersonName(String raw) {
  final name = normalizeKoreanPersonName(stripTrailingKoreanParticles(raw));
  if (isKoreanPronounWithParticle(raw.trim())) return false;
  if (isPetDescriptorToken(name) || isPetOrdinalToken(name)) return false;
  if (isKnownFoodLabel(name)) return false;
  if (isKnownContentLabel(name)) return false;
  if (isKnownInterestLabel(name)) return false;
  if (isKnownEmotionLabel(name)) return false;
  if (isMealTimeGraphToken(name)) return false;
  if (isPhoneCallGraphToken(name)) return false;
  if (isFamilyRelationTerm(name)) return true;
  if (isMedicalNonPersonToken(name)) return false;
  if (name.length < 2 || name.length > 4) return false;
  if (!RegExp(r'^[가-힣]+$').hasMatch(name)) return false;
  if (koreanPersonNameStopWords.contains(name)) return false;
  if (RegExp(r'(?:한다|했다|긴다|는다|겠다|싶다)$').hasMatch(name)) return false;
  if (isGraphMorphologyJunkToken(name)) return false;
  // 교·천·산·강·댐 등은 장소 시설 — 인명으로 보지 않음 (월영교·길안천).
  if (RegExp(r'(?:교|천|산|강|댐|봉|령|고개|해변|공원|시장|역)$').hasMatch(name) &&
      name.length >= 3) {
    return false;
  }
  // 고스톰 등 활동 토큰.
  if (const {'고스톰', '고스돔', '고도리', '고스톱'}.contains(name)) return false;
  if (looksLikeKoreanPlaceName(name)) {
    if (name.length <= 3 && name.endsWith('호')) {
      // 인명과 겹치는 짧은 장소 접미사(대호 등)는 인명 우선.
    } else if (looksLikePersonNameEndingInDong(name) || looksLikePersonNameEndingInHo(name)) {
      // 홍길동·정준호 등 성+이름.
    } else {
      return false;
    }
  }
  if (isJunkEntityOrKeyword(name)) return false;
  return true;
}

bool isLikelyPetNameInContext(String raw, String context) {
  final token = normalizeKoreanPersonName(stripTrailingKoreanParticles(raw));
  if (token.length < 2 || token.length > 4) return false;
  if (!RegExp(r'^[가-힣]+$').hasMatch(token)) return false;
  final text = context.trim();
  if (text.isEmpty) return false;

  final hasPetContext = kPetContextKeywords.any(text.contains);
  if (!hasPetContext) return false;

  if (kKnownPetNames.contains(token)) return true;

  final escaped = RegExp.escape(token);
  if (RegExp('(?:반려견|반려묘|강아지|고양이|노견|애견)\\s*(?:이름은|이름|인)?\\s*$escaped').hasMatch(text)) {
    return true;
  }
  if (RegExp('$escaped(?:이|가|은|는|와|과|랑|이랑)?\\s*(?:반려견|반려묘|강아지|고양이|노견|애견)').hasMatch(text)) {
    return true;
  }
  return false;
}

List<String> extractPetNamesFromText(String text) {
  final value = text.trim();
  if (value.isEmpty) return const [];
  if (!textHasPetNarrativeContext(value)) return const [];

  final out = <String>[];
  final seen = <String>{};
  void add(String? raw) {
    final token = normalizeKoreanPersonName(stripTrailingKoreanParticles(raw?.trim() ?? ''));
    if (token.length < 2 || token.length > 4) return;
    if (!RegExp(r'^[가-힣]+$').hasMatch(token)) return;
    if (isPetOrdinalToken(token) || isPetDescriptorToken(token)) return;
    if (isFamilyRelationTerm(token)) return;
    if (koreanPersonNameStopWords.contains(token)) return;
    if (!isLikelyPetNameInContext(token, value) &&
        !kKnownPetNames.contains(token) &&
        !mentionedAsPetInText(token, value)) {
      return;
    }
    if (seen.add(token)) out.add(token);
  }

  for (final match
      in RegExp(r'(?:첫째|둘째|셋째|넷째)\s+반려견\s+([가-힣]{2,4})').allMatches(value)) {
    add(match.group(1));
  }
  for (final match in RegExp(r'반려견\s+([가-힣]{2,4})').allMatches(value)) {
    add(match.group(1));
  }
  for (final match in RegExp(r'([가-힣]{2,4})(?:을|를)\s*(?:입양|데려왔)').allMatches(value)) {
    add(match.group(1));
  }
  for (final match in RegExp(r'([가-힣]{2,4})(?:은|는|이|가)\s+[가-힣]{2,4}(?:을|를)').allMatches(value)) {
    add(match.group(1));
  }
  for (final match in RegExp(r'([가-힣]{2,4})(?:을|를)\s*(?:안고|돌봐)').allMatches(value)) {
    add(match.group(1));
  }
  for (final match in RegExp(r'(?:반려견|강아지|노견|애견)\s*(?:이름은|이름|인)?\s*([가-힣]{2,4})').allMatches(value)) {
    add(match.group(1));
  }
  for (final match in RegExp(r'(?:반려견|강아지|노견|애견)\s*(?:이름은|이름|인)?\s*([가-힣]{2,4}(?:\s*[,와]\s*[가-힣]{2,4})+)').allMatches(value)) {
    for (final part in match.group(1)!.split(RegExp(r'[,와]'))) {
      add(part);
    }
  }
  for (final match in RegExp(r'([가-힣]{2,4})\s*와\s*([가-힣]{2,4})').allMatches(value)) {
    final a = match.group(1)!;
    final b = match.group(2)!;
    if (kKnownPetNames.contains(a) || kKnownPetNames.contains(b) || textHasPetNarrativeContext(value)) {
      add(a);
      add(b);
    }
  }
  for (final name in kKnownPetNames) {
    if (value.contains(name)) add(name);
  }
  return out;
}

String normalizeKoreanPersonName(String raw) {
  var name = _stripPersonTitlesAndHonorifics(raw.trim());
  if (isFamilyRelationTerm(name)) return name;
  name = stripTrailingKoreanParticles(name);
  if (name.length >= 3 && (name.endsWith('이') || name.endsWith('가'))) {
    final stem = name.substring(0, name.length - 1);
    if (stem.length >= 2 &&
        (!looksLikeKoreanPlaceName(stem) || looksLikePersonNameEndingInDong(stem))) {
      name = stem;
    }
  }
  return name;
}

/// 인명 — 조사·호칭·직함·「삼성 이재용」형 조직+인명.
String _stripPersonTitlesAndHonorifics(String raw) {
  var name = raw.trim().replaceAll(RegExp(r'[.,!?…·]+$'), '');
  if (name.isEmpty || isFamilyRelationTerm(name)) return name;

  name = stripTrailingKoreanParticles(name);

  if (name.endsWith('님') && name.length > 2) {
    name = name.substring(0, name.length - 1);
  }
  if (name.endsWith('씨') && name.length > 2) {
    name = name.substring(0, name.length - 1);
  }

  const titles = [
    '교수', '대표', '회장', '부회장', '사장', '부사장', '이사', '상무', '전무',
    '부장', '차장', '과장', '팀장', '실장', '원장', '소장', '국장', '처장',
    'CEO', 'CTO', 'CFO', 'COO', '박사', '선생', '선생님',
  ];

  final spaceTitle = RegExp(
    '^([가-힣]{2,4})\\s+(?:${titles.map(RegExp.escape).join('|')})\$',
    caseSensitive: false,
  );
  final spaceMatch = spaceTitle.firstMatch(name);
  if (spaceMatch != null) {
    name = spaceMatch.group(1)!;
  }

  for (final title in titles) {
    if (name.endsWith(title) && name.length > title.length + 1) {
      final stem = name.substring(0, name.length - title.length).trim();
      if (stem.length >= 2) {
        name = stem;
        break;
      }
    }
  }

  final orgPerson = RegExp(r'^[가-힣A-Za-z0-9]{2,10}\s+([가-힣]{2,4})$');
  final orgMatch = orgPerson.firstMatch(name);
  if (orgMatch != null) {
    final person = orgMatch.group(1)!;
    // 「예린 엄마」같은 복합 가족 호칭은 유지. 「삼성 이재용」만 인명으로 축약.
    if (!isFamilyRelationTerm(person) && isLikelyKoreanPersonName(person)) {
      name = person;
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

  const titleSuffix = r'(?:간호과장|간호팀장|팀장|과장|원장|부장|이사|대리|사원)?';
  final listPattern = RegExp(
    '([가-힣]{2,4}$titleSuffix(?:\\s*,\\s*[가-힣]{2,4}$titleSuffix){1,7})',
  );
  for (final match in listPattern.allMatches(text)) {
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
      final trimmed = part.trim();
      if (trimmed == '나' || trimmed.startsWith('나 ')) {
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
