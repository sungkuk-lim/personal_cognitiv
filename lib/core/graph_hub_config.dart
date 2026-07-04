/// 관계망 허브 보기 방식 — 기억 중심 vs 이벤트 중심.
enum GraphHubViewMode {
  /// 기억 카드가 허브, 위성이 사람·장소·감정.
  memoryHub,
  /// 이벤트가 허브, 사람·장소·감정·기억이 연결됨.
  eventHub,
}

GraphHubViewMode graphHubViewModeFromString(String? raw) {
  switch (raw) {
    case 'event':
      return GraphHubViewMode.eventHub;
    default:
      return GraphHubViewMode.memoryHub;
  }
}

String graphHubViewModeToString(GraphHubViewMode mode) {
  switch (mode) {
    case GraphHubViewMode.memoryHub:
      return 'memory';
    case GraphHubViewMode.eventHub:
      return 'event';
  }
}
