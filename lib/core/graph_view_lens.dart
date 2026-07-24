/// 관계망 렌즈 — 동일 데이터, 다른 관점.
///
/// UI에는 **사람 | 기억**만 노출합니다. `aiInsight`·`timeline`은 하위 호환용이며
/// 로드·저장 시 기억 렌즈로 정규화됩니다. AI 인사이트는 설정「관계망 AI」토글로 켭니다.
enum GraphViewLens {
  /// 누구와의 기억인가 (사람 중심 허브).
  person,
  /// 어떤 사건·기억인가 (기억 허브).
  memory,
  /// (레거시) AI 인사이트 — 기억 렌즈 + 관계망 AI 토글로 대체.
  aiInsight,
  /// (레거시) 타임라인 — 기억 렌즈로 매핑.
  timeline,
}

GraphViewLens graphViewLensFromString(String? raw) {
  switch (raw) {
    case 'person':
      return GraphViewLens.person;
    case 'ai':
    case 'timeline':
      return GraphViewLens.memory;
    default:
      return GraphViewLens.memory;
  }
}

String graphViewLensToString(GraphViewLens lens) {
  switch (lens) {
    case GraphViewLens.person:
      return 'person';
    case GraphViewLens.memory:
    case GraphViewLens.aiInsight:
    case GraphViewLens.timeline:
      return 'memory';
  }
}
