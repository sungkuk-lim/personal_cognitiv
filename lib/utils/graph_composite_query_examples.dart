import 'memory_query.dart';

/// Phase 2 복합 질의 — UI 힌트·QA·파서 회귀용 20문장.
class GraphCompositeQueryExample {
  const GraphCompositeQueryExample({
    required this.query,
    this.minDimensions = 2,
  });

  final String query;
  final int minDimensions;
}

const kGraphCompositeQueryExamplesKo = [
  GraphCompositeQueryExample(query: '민수랑 행복했던 식사만 보여줘'),
  GraphCompositeQueryExample(query: '어머니와 광안리에서 찍은 사진'),
  GraphCompositeQueryExample(query: '지영이랑 카페에서 마신 커피 기억'),
  GraphCompositeQueryExample(query: '작년 여름 가족 여행'),
  GraphCompositeQueryExample(query: '성수동에서 피자 먹고 영화 본 날'),
  GraphCompositeQueryExample(query: '최근 30일 슬펐던 기억'),
  GraphCompositeQueryExample(query: '철수와 을지로 삼겹살 저녁'),
  GraphCompositeQueryExample(query: '올해 회사 회식'),
  GraphCompositeQueryExample(query: '행복했던 산책 사진만'),
  GraphCompositeQueryExample(query: '민수와 지영이 함께한 기억'),
  GraphCompositeQueryExample(query: '부산 해수욕장 여름 나들이'),
  GraphCompositeQueryExample(query: '독서 모임에서 만난 사람'),
  GraphCompositeQueryExample(query: '비 오는 날 카페에서 읽은 책'),
  GraphCompositeQueryExample(query: '친구와 공연 본 뒤 한강 산책'),
  GraphCompositeQueryExample(query: '어머니 생일 식사'),
  GraphCompositeQueryExample(query: '최근에 찍은 가족 사진'),
  GraphCompositeQueryExample(query: '영화 본 날 기쁜 기억'),
  GraphCompositeQueryExample(query: '작년 봄 벚꽃 나들이'),
  GraphCompositeQueryExample(query: '민수와 성수동 카페 보드게임'),
  GraphCompositeQueryExample(query: '해리 포터 추천받고 영화제 가기로 한 날'),
];

const kGraphCompositeQueryExamplesEn = [
  GraphCompositeQueryExample(query: 'Happy meals with Minsu'),
  GraphCompositeQueryExample(query: 'Photos with mom at Gwangalli'),
  GraphCompositeQueryExample(query: 'Coffee at a cafe with Jiyoung'),
  GraphCompositeQueryExample(query: 'Family trip last summer'),
  GraphCompositeQueryExample(query: 'Pizza and movie in Seongsu'),
  GraphCompositeQueryExample(query: 'Sad memories from the last 30 days'),
  GraphCompositeQueryExample(query: 'Samgyeopsal dinner with Cheolsu in Euljiro'),
  GraphCompositeQueryExample(query: 'Work dinners this year'),
  GraphCompositeQueryExample(query: 'Happy walk photos only'),
  GraphCompositeQueryExample(query: 'Memories with Minsu and Jiyoung'),
  GraphCompositeQueryExample(query: 'Summer outing at Busan beach'),
  GraphCompositeQueryExample(query: 'People from book club'),
  GraphCompositeQueryExample(query: 'Reading at a cafe on a rainy day'),
  GraphCompositeQueryExample(query: 'Concert then Han River walk with friends'),
  GraphCompositeQueryExample(query: "Mom's birthday dinner"),
  GraphCompositeQueryExample(query: 'Recent family photos'),
  GraphCompositeQueryExample(query: 'Joyful days after watching a movie'),
  GraphCompositeQueryExample(query: 'Cherry blossom outing last spring'),
  GraphCompositeQueryExample(query: 'Board games at Seongsu cafe with Minsu'),
  GraphCompositeQueryExample(query: 'Harry Potter recommendation and film festival plan'),
];

List<GraphCompositeQueryExample> graphCompositeQueryExamples(String localeCode) {
  return localeCode == 'ko' ? kGraphCompositeQueryExamplesKo : kGraphCompositeQueryExamplesEn;
}

/// 검색 빈 화면·온보딩용 대표 6문장.
List<String> graphCompositeQueryHints(String localeCode, {int count = 6}) {
  return graphCompositeQueryExamples(localeCode).take(count).map((e) => e.query).toList();
}
