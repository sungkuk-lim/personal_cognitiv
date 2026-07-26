import '../models/memory.dart';
import 'korean_person_names.dart';
import 'ocr_utils.dart';
import 'photo_memory_format.dart';
import 'recall_anchor.dart';

/// 사진·촬영 기억 — 촬영 GPS를 카드·회상에 사용합니다.
bool isPhotoCaptureMemoryType(String type) {
  final t = type.trim().toLowerCase();
  return t == 'image' || t == 'photo' || t == 'camera';
}

bool isGenericCapturePlaceLabel(String? label) {
  final v = label?.trim() ?? '';
  if (v.isEmpty) return true;
  if (isLatLngLabel(v)) return true;
  const generic = {'지금 위치', 'current location', 'Current location', 'GPS', 'gps'};
  return generic.contains(v);
}

bool isMeaningfulPlaceLabel(String? label) {
  final v = label?.trim() ?? '';
  if (v.isEmpty || isGenericCapturePlaceLabel(v)) return false;
  if (isLikelyLotNumber(v)) return false;
  return true;
}

/// 본문·사용자 입력·회상 앵커에 확정된 장소명 (GPS 역지오코딩보다 우선).
String? pinnedPlaceLabelForMemory(Memory memory, {String localeCode = 'ko'}) {
  final recall = memory.recallPlaceLabel?.trim();
  if (isMeaningfulPlaceLabel(recall)) return recall;

  final story = primaryStoryPlaceLabel(memory, localeCode: localeCode);
  if (story != null && story.trim().isNotEmpty) return story.trim();

  return placeLabelFromEntities(memory);
}

String? placeLabelFromEntities(Memory memory) {
  for (final entity in sanitizeEntities(memory.entities)) {
    if (isLatLngLabel(entity) || isLikelyLotNumber(entity)) continue;
    if (entity.length < 2 || entity.length > 24) continue;
    if (isLikelyKoreanPersonName(entity)) continue;
    if (looksLikeKoreanPlaceName(entity) || entity.contains(' ') || entity.contains('해수욕장')) {
      return entity;
    }
  }
  return null;
}

/// 카드·상세에 GPS 역지오코딩 주소를 쓸지 여부.
bool memoryUsesGpsForDisplay(Memory memory, {String localeCode = 'ko'}) {
  if (isPhotoCaptureMemoryType(memory.type)) {
    return memory.lat != null && memory.lng != null;
  }
  if (isMeaningfulPlaceLabel(memory.recallPlaceLabel)) return true;
  if (primaryStoryPlaceLabel(memory, localeCode: localeCode) != null) return true;
  if (placeLabelFromEntities(memory) != null) return true;
  return false;
}

/// 표시·캐시 조회용 좌표 — recall 앵커 우선, 장소 무관 음성·텍스트는 null.
({double lat, double lng})? displayCoordinatesForMemory(Memory memory, {String localeCode = 'ko'}) {
  if (memory.recallLat != null && memory.recallLng != null) {
    return (lat: memory.recallLat!, lng: memory.recallLng!);
  }
  if (!memoryUsesGpsForDisplay(memory, localeCode: localeCode)) return null;
  if (memory.lat != null && memory.lng != null) {
    return (lat: memory.lat!, lng: memory.lng!);
  }
  return null;
}

/// 저장 시 lat/lng 필드에 촬영 GPS를 붙일지 — 사진 또는 본문에 장소가 있을 때만.
bool shouldPersistCaptureGpsOnSave({
  required String type,
  required String content,
  String localeCode = 'ko',
}) {
  if (isPhotoCaptureMemoryType(type)) return true;
  if (extractPlaceHintFromOcr(content.trim()) != null) return true;
  if (primaryStoryPlaceLabel(
        Memory(
          id: '',
          userId: '',
          content: content,
          summary: content,
          entities: const [],
          createdAt: DateTime.now(),
          type: type,
        ),
        localeCode: localeCode,
      ) !=
      null) {
    return true;
  }
  return false;
}

bool isUnknownPlaceLabel(String label, String localeCode) =>
    label.trim() == (localeCode == 'ko' ? '장소 미상' : 'Unknown place');
