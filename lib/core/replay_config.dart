/// 회상 탭 표시 방식.
enum ReplayViewMode {
  /// 월별 그리드 → 공통 상세 (편집은 타임라인에서).
  shared,
  /// 월별 그리드 → 사진·메모만 큰 가벼운 상세.
  light,
  /// 월별 그리드 → 상세 없이 확대·슬라이드 갤러리.
  gallery,
}

ReplayViewMode replayViewModeFromString(String? raw) {
  switch (raw) {
    case 'light':
      return ReplayViewMode.light;
    case 'gallery':
      return ReplayViewMode.gallery;
    default:
      return ReplayViewMode.shared;
  }
}

String replayViewModeToString(ReplayViewMode mode) {
  switch (mode) {
    case ReplayViewMode.shared:
      return 'shared';
    case ReplayViewMode.light:
      return 'light';
    case ReplayViewMode.gallery:
      return 'gallery';
  }
}
