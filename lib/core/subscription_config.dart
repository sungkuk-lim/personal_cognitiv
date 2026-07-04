/// MemoryOS Pro 구독·쿼터 설정 (서버 openai-proxy·consume_ai_quota 와 동기화).
class SubscriptionConfig {
  SubscriptionConfig._();

  static const String entitlementPro = 'pro';

  /// Google Play / RevenueCat 상품 ID (Play Console·RevenueCat에서 동일하게 등록).
  static const String productMonthly = 'memoryos_pro_monthly';
  static const String productAnnual = 'memoryos_pro_annual';

  static const int quotaChatMonthly = 500;
  static const int quotaEmbeddingMonthly = 300;
  static const int quotaVisionMonthly = 100;

  static const List<String> proBenefitKeys = [
    'pro_benefit_cloud',
    'pro_benefit_search',
    'pro_benefit_vision',
    'pro_benefit_graph_ai',
    'pro_benefit_sync',
  ];
}
