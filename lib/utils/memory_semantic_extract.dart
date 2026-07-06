/// 본문에서 활동·이벤트·관심사·콘텐츠·음식·취미·감정 등 의미 카테고리를 규칙 기반으로 추출합니다.
class MemorySemanticScan {
  const MemorySemanticScan({
    this.events = const [],
    this.interests = const [],
    this.contents = const [],
    this.food = const [],
    this.hobbies = const [],
    this.emotions = const [],
    this.activities = const [],
  });

  final List<String> events;
  final List<String> interests;
  final List<String> contents;
  final List<String> food;
  final List<String> hobbies;
  final List<String> emotions;
  final List<String> activities;
}

const kSemanticEventLexicon = {
  '시험', '생일', '결혼식', '졸업식', '입학식', '회식', '모임', '공연', '축제', '기념일',
  '여행', '나들이', '워크숍', '교육', '회의', '파티', '행사', '돌잔치', '장례', '개업',
};

const kSemanticInterestLexicon = {
  'AI', '인공지능', '투자', '주식', '디자인', '자동차', '컴퓨터', '프로그래밍', '코딩',
  '요리', '패션', '뷰티', '건강', '재테크', '부동산', '창업', '스타트업', '과학', '역사',
  '정치', '경제', '스포츠', '축구', '야구', '골프', '테니스', '반려동물', '반려견',
};

const kSemanticContentLexicon = {
  '영화', '드라마', '책', '소설', '만화', '웹툰', '유튜브', '팟캐스트', '넷플릭스',
  '음악', '앨범', '게임', '뉴스', '다큐', '공연', '뮤지컬', '전시',
};

const kSemanticFoodLexicon = {
  '탕수육', '자장면', '치킨', '삼겹살', '장어', '조개', '회', '라면', '피자', '커피',
  '빵', '떡볶이', '김치찌개', '된장찌개', '불고기', '냉면', '초밥', '파스타', '스테이크',
  '옥수수', '감자', '고구마', '계란', '과일',
};

const kSemanticHobbyLexicon = {
  '등산', '독서', '게임', '캠핑', '낚시', '요리', '사진', '그림', '음악', '영화',
  '러닝', '수영', '자전거', '여행', '베이킹', '명상', '요가', '헬스', '골프',
};

const kSemanticEmotionLexicon = {
  '행복', '기쁨', '슬픔', '감동', '그리움', '설렘', '후회', '감사', '실망', '평온',
  '즐거움', '뿌듯', '아쉬움', '화남', '걱정', '불안', '희망', '자랑', '응원',
};

const kSemanticActivityLexicon = {
  '운동', '공부', '산책', '쇼핑', '관람', '여행', '등산', '회식', '회의',
  '드라이브', '운전', '청소', '정리', '요리', '촬영',
};

bool isKnownFoodLabel(String label) => kSemanticFoodLexicon.contains(label.trim());

bool isKnownContentLabel(String label) => kSemanticContentLexicon.contains(label.trim());

/// 콘텐츠·음식·장소 토큰 — 인물 후보에서 제외.
bool isNonPersonGraphToken(String label) {
  final v = label.trim();
  return isKnownFoodLabel(v) || isKnownContentLabel(v);
}

MemorySemanticScan extractSemanticFromText(String text) {
  final value = text.trim();
  if (value.isEmpty) return const MemorySemanticScan();

  final events = <String>[];
  final interests = <String>[];
  final contents = <String>[];
  final food = <String>[];
  final hobbies = <String>[];
  final emotions = <String>[];
  final activities = <String>[];

  void scanLexicon(Set<String> lexicon, List<String> target) {
    for (final word in lexicon) {
      if (word == '영화' && RegExp(r'[가-힣]*영화제').hasMatch(value)) continue;
      if (value.contains(word)) target.add(word);
    }
  }

  scanLexicon(kSemanticEventLexicon, events);
  scanLexicon(kSemanticInterestLexicon, interests);
  scanLexicon(kSemanticContentLexicon, contents);
  scanLexicon(kSemanticFoodLexicon, food);
  scanLexicon(kSemanticHobbyLexicon, hobbies);
  scanLexicon(kSemanticEmotionLexicon, emotions);
  scanLexicon(kSemanticActivityLexicon, activities);

  final exam = _extractExamEventLabel(value);
  if (exam != null) {
    events.remove('시험');
    events.insert(0, exam);
    activities.remove('시험');
    interests.removeWhere((i) => exam.contains(i) || i.contains('능력'));
  } else if (value.contains('시험') && !activities.contains('시험')) {
    activities.add('시험');
  }

  final certInterest = exam == null ? _extractCertificationInterest(value) : null;
  if (certInterest != null) interests.insert(0, certInterest);

  if (value.contains('공부') && !activities.contains('공부')) {
    activities.add('공부');
  }

  _dedupeSemanticAcrossCategories(
    events: events,
    interests: interests,
    contents: contents,
    food: food,
    hobbies: hobbies,
    activities: activities,
  );

  // 시험·자격 이벤트가 있으면 짧은 중복 카테고리 제거.
  if (exam != null) {
    events.removeWhere((e) => e != exam && (exam.contains(e) || e.contains('시험')));
    activities.removeWhere((a) => exam.contains(a) || a == '시험');
    interests.removeWhere((i) => exam.contains(i));
  }

  return MemorySemanticScan(
    events: _dedupeOrdered(events).take(1).toList(),
    interests: _dedupeOrdered(interests).take(3).toList(),
    contents: _dedupeOrdered(contents).take(3).toList(),
    food: _dedupeOrdered(food).take(2).toList(),
    hobbies: _dedupeOrdered(hobbies).take(2).toList(),
    emotions: _dedupeOrdered(emotions).take(2).toList(),
    activities: _dedupeOrdered(activities).take(3).toList(),
  );
}

void _dedupeSemanticAcrossCategories({
  required List<String> events,
  required List<String> interests,
  required List<String> contents,
  required List<String> food,
  required List<String> hobbies,
  required List<String> activities,
}) {
  for (final item in food) {
    hobbies.remove(item);
    contents.remove(item);
    activities.remove(item);
    interests.remove(item);
  }
  for (final item in contents) {
    hobbies.remove(item);
    activities.remove(item);
    interests.remove(item);
  }
  for (final item in events) {
    hobbies.remove(item);
  }
}

String? _extractExamEventLabel(String text) {
  final searchText = _textAfterSubject(text).replaceFirst(RegExp(r'^(?:오늘|내일|어제)\s+'), '');
  final match = RegExp(
    r'([가-힣A-Za-z0-9]+(?:\s+[가-힣A-Za-z0-9]+){0,5}\s*시험)',
  ).firstMatch(searchText);
  if (match != null) {
    final label = match.group(1)!.trim();
    if (label.length >= 3) return label;
  }
  return null;
}

String? _extractCertificationInterest(String text) {
  final searchText = _textAfterSubject(text).replaceFirst(RegExp(r'^(?:오늘|내일|어제)\s+'), '');
  final match = RegExp(
    r'([가-힣A-Za-z0-9]+(?:\s+[가-힣A-Za-z0-9]+){0,3}\s*능력)\s*(?:\d+\s*급\s*)?시험',
  ).firstMatch(searchText);
  if (match != null) return match.group(1)!.trim();
  return null;
}

String _textAfterSubject(String text) {
  final subject = RegExp(r'^[^,.!?]{1,24}?(?:이|가)\s+').firstMatch(text.trim());
  if (subject == null) return text.trim();
  return text.substring(subject.end).trim();
}

List<String> _dedupeOrdered(List<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    final key = item.trim();
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(key);
  }
  return out;
}
