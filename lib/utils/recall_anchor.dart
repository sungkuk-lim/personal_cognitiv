import 'dart:math' as math;

import '../models/memory.dart';
import 'korean_person_names.dart';
import 'memory_entity_extract.dart';
import 'photo_memory_format.dart';

/// 기억 본문·엔티티에서 회상 앵커로 쓸 장소명을 고릅니다.
String? primaryStoryPlaceLabel(Memory memory, {String localeCode = 'ko'}) {
  final bundle = extractMemoryEntities(memory, localeCode: localeCode);
  String? best;
  var bestScore = 0;
  void consider(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.length < 2) return;
    if (!looksLikeKoreanPlaceName(value) && !value.contains('해수욕장') && !value.contains('공원')) {
      return;
    }
    var score = value.length;
    if (value.contains('해수욕장') || value.contains('공원') || value.contains('교')) score += 12;
    if (score > bestScore) {
      bestScore = score;
      best = value;
    }
  }

  for (final place in bundle.places) {
    consider(place);
  }
  for (final entity in userVisibleEntityLabels(memory)) {
    consider(entity);
  }
  consider(extractPlaceHintFromOcr(memory.content));
  return best;
}

bool placeLabelsOverlap(String? a, String? b) {
  final x = a?.trim() ?? '';
  final y = b?.trim() ?? '';
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  return x.contains(y) || y.contains(x);
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// 촬영·입력 GPS와 이야기 장소가 다른지 (회상 확인 필요).
bool shouldConfirmRecallPlace({
  required String? capturePlaceLabel,
  required String storyPlaceLabel,
  double? captureLat,
  double? captureLng,
  double? storyLat,
  double? storyLng,
}) {
  final story = storyPlaceLabel.trim();
  if (story.isEmpty) return false;

  if (captureLat == null || captureLng == null) return storyLat != null;

  if (placeLabelsOverlap(capturePlaceLabel, story)) return false;

  if (storyLat != null && storyLng != null) {
    final dist = distanceMeters(captureLat, captureLng, storyLat, storyLng);
    if (dist <= 500) return false;
  }

  return true;
}

/// 회상 알림에 쓸 좌표 — recall 앵커 우선, 없으면 기존 GPS(레거시).
({double lat, double lng})? effectiveRecallCoordinates(Memory memory) {
  if (!memory.recallEnabled) return null;
  if (memory.recallLat != null && memory.recallLng != null) {
    return (lat: memory.recallLat!, lng: memory.recallLng!);
  }
  if (memory.lat != null && memory.lng != null) {
    return (lat: memory.lat!, lng: memory.lng!);
  }
  return null;
}

enum RecallAnchorStatus { active, needsPlace, disabled, none }

RecallAnchorStatus recallAnchorStatus(Memory memory, {String localeCode = 'ko'}) {
  if (!memory.recallEnabled) return RecallAnchorStatus.disabled;

  if (memory.recallLat != null && memory.recallLng != null) {
    return RecallAnchorStatus.active;
  }

  final story = primaryStoryPlaceLabel(memory, localeCode: localeCode);
  if (story != null &&
      story.isNotEmpty &&
      memory.lat != null &&
      memory.lng != null &&
      shouldConfirmRecallPlace(
        capturePlaceLabel: memory.recallPlaceLabel,
        storyPlaceLabel: story,
        captureLat: memory.lat,
        captureLng: memory.lng,
      )) {
    return RecallAnchorStatus.needsPlace;
  }

  if (effectiveRecallCoordinates(memory) != null) {
    return RecallAnchorStatus.active;
  }
  return RecallAnchorStatus.none;
}

String? recallAnchorLabel(Memory memory, {String localeCode = 'ko'}) {
  final explicit = memory.recallPlaceLabel?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  return primaryStoryPlaceLabel(memory, localeCode: localeCode);
}
