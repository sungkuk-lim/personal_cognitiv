/// 관계망 대규모 기억 시 성능·가독성 가드.
abstract final class GraphScaleConfig {
  /// 이 수 이상이면 「전체」 기간 선택 시 성능 배너를 표시합니다.
  static const int performanceBannerThreshold = 80;

  /// 레이아웃에 포함할 기억 상한 (초과 시 최신순 잘림 + 안내).
  static const int maxLayoutMemories = 200;

  /// 소규모 그래프 — 위성을 처음부터 펼칩니다.
  static const int autoExpandSatelliteMemoryCount = 6;
}
