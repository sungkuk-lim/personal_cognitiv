import '../models/memory.dart';
import 'memory_place_policy.dart';
import 'memory_relative_date.dart';
import 'recall_anchor.dart';

/// 저장 직전 날짜·장소 확인 시트 표시 여부.
bool shouldShowMemoryRefinementSheet(Memory draft, {String localeCode = 'ko'}) {
  if (isPhotoCaptureMemoryType(draft.type)) return true;

  final hasRelativeDate = relativeDayOffsetFromText(draft.content) != null;
  final storyPlace = primaryStoryPlaceLabel(draft, localeCode: localeCode);
  final hasStoryPlace = storyPlace != null && storyPlace.trim().isNotEmpty;

  return !hasRelativeDate || !hasStoryPlace;
}

/// 장소 선택 UI 초기값.
MemoryPlaceMode initialPlaceModeForRefinement({
  required Memory draft,
  double? captureLat,
  double? captureLng,
  String? storyPlace,
}) {
  if (isPhotoCaptureMemoryType(draft.type) && captureLat != null && captureLng != null) {
    return MemoryPlaceMode.captureHere;
  }
  if (storyPlace != null && storyPlace.trim().isNotEmpty) {
    return MemoryPlaceMode.custom;
  }
  return MemoryPlaceMode.none;
}

enum MemoryPlaceMode { none, captureHere, custom }

class MemoryRefinementResult {
  const MemoryRefinementResult({
    required this.date,
    required this.placeMode,
    this.customPlace,
    required this.summary,
  });

  final DateTime date;
  final MemoryPlaceMode placeMode;
  final String? customPlace;
  final String summary;
}
