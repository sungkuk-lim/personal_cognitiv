/// MemoryOS Pro 구독·쿼터 설정 (서버 openai-proxy·consume_ai_quota 와 동기화).
class SubscriptionConfig {
  SubscriptionConfig._();

  static const String entitlementPro = 'pro';

  /// Google Play / RevenueCat 상품 ID (Play Console·RevenueCat에서 동일하게 등록).
  static const String productMonthly = 'memoryos_pro_monthly';
  static const String productAnnual = 'memoryos_pro_annual';

  /// AI 월간 쿼터 — 헤비 유저 손해 방지용 상한 (서버 consume_ai_quota와 동일).
  /// 초과 시 다음 달 1일(UTC)까지 AI 호출 차단. 로컬 기억·관계망 골격은 계속 사용 가능.
  static const int quotaChatMonthly = 500;
  static const int quotaEmbeddingMonthly = 300;
  static const int quotaVisionMonthly = 100;

  /// 사용량 경고 임계치 (UI 소프트 알림).
  static const double quotaWarnRatio = 0.8;

  /// 소프트런치 권장 소비자 가격 (Play Console에 등록 — 앱에 하드코딩하지 않음).
  static const String suggestedMonthlyKrw = '5900';
  static const String suggestedAnnualKrw = '59000';

  /// OpenAI 대략 원가 완충용 — 월 Pro 1명당 서버 비용이 구독가의 ~30%를 넘기지 않도록 쿼터 설계.
  static const String pricingNotes =
      '월 ₩5,900 / 연 ₩59,000 · chat 500 · embed 300 · vision 100';

  static const List<String> proBenefitKeys = [
    'pro_benefit_cloud',
    'pro_benefit_insights',
    'pro_benefit_composite',
    'pro_benefit_recall',
    'pro_benefit_wrapped',
    'pro_benefit_theme_hub',
    'pro_benefit_graph_ai',
    'pro_benefit_search',
  ];
}
