import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../services/place_lookup_service.dart';
import 'korean_person_names.dart';
import 'memory_grouping.dart';
import 'memory_place_policy.dart';
import 'ocr_utils.dart';

const String prefMemoryPlaceNames = 'memory_place_names';
const String prefMemoryPlaceFullAddresses = 'memory_place_full_addresses';

String latLngCacheKey(double lat, double lng) =>
    '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

Map<String, String> readMemoryPlaceNames(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryPlaceNames);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    return {};
  }
}

Map<String, String> readMemoryPlaceFullAddresses(SharedPreferences prefs) {
  final raw = prefs.getString(prefMemoryPlaceFullAddresses);
  if (raw == null) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    return {};
  }
}

Future<void> saveMemoryPlaceNames(SharedPreferences prefs, Map<String, String> names) async {
  await prefs.setString(prefMemoryPlaceNames, jsonEncode(names));
}

Future<void> saveMemoryPlaceFullAddresses(SharedPreferences prefs, Map<String, String> addresses) async {
  await prefs.setString(prefMemoryPlaceFullAddresses, jsonEncode(addresses));
}

String? _placeNameFromCoords(({double lat, double lng}) coords, Map<String, String> cache) {
  return cache[latLngCacheKey(coords.lat, coords.lng)];
}

String? _fullAddressFromCoords(({double lat, double lng}) coords, Map<String, String> cache) {
  return cache[latLngCacheKey(coords.lat, coords.lng)];
}

/// 표시 정책과 무관하게 캐시에 좌표가 있으면 주소 조회에 사용합니다.
({double lat, double lng})? _coordsForAddressLookup(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  String localeCode = 'ko',
}) {
  final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
  if (coords != null) return coords;
  if (memory.lat == null || memory.lng == null) return null;
  final key = latLngCacheKey(memory.lat!, memory.lng!);
  if (fullAddressCache.containsKey(key) || placeCache.containsKey(key)) {
    return (lat: memory.lat!, lng: memory.lng!);
  }
  return null;
}

String? placeNameFromCache(Memory memory, Map<String, String> cache, {String localeCode = 'ko'}) {
  final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
  if (coords == null) return null;
  return _placeNameFromCoords(coords, cache);
}

String? fullAddressFromCache(Memory memory, Map<String, String> cache, {String localeCode = 'ko'}) {
  final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
  if (coords == null) return null;
  return _fullAddressFromCoords(coords, cache);
}

String? _addressFromDisplayCoords(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  String localeCode = 'ko',
}) {
  final coords = _coordsForAddressLookup(
    memory,
    placeCache,
    fullAddressCache,
    localeCode: localeCode,
  );
  if (coords == null) return null;

  final full = _fullAddressFromCoords(coords, fullAddressCache);
  if (full != null && full.isNotEmpty) return full;

  final short = _placeNameFromCoords(coords, placeCache);
  if (short != null && short.isNotEmpty && !isLikelyLotNumber(short) && !isLatLngLabel(short)) {
    return short;
  }
  return null;
}

/// 역지오코딩 결과를 캐시에 저장합니다. (표시용, 비용 없음)
Future<Map<String, String>> warmPlaceNamesForMemories(
  List<Memory> memories,
  SharedPreferences prefs, {
  String localeCode = 'ko',
}) async {
  final cache = {...readMemoryPlaceNames(prefs)};
  var changed = false;

  final seen = <String>{};
  for (final memory in memories) {
    final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
    if (coords == null) continue;
    final key = latLngCacheKey(coords.lat, coords.lng);
    if (!seen.add(key)) continue;
    if (cache.containsKey(key) && cache[key]!.trim().isNotEmpty) continue;

    final name = await PlaceLookupService.resolvePlaceName(
      coords.lat,
      coords.lng,
      localeCode: localeCode,
    );
    if (name != null && name.trim().isNotEmpty) {
      cache[key] = name.trim();
      changed = true;
    }
  }

  if (changed) await saveMemoryPlaceNames(prefs, cache);
  return cache;
}

Future<Map<String, String>> warmPlaceFullAddressesForMemories(
  List<Memory> memories,
  SharedPreferences prefs, {
  String localeCode = 'ko',
}) async {
  final cache = {...readMemoryPlaceFullAddresses(prefs)};
  var changed = false;

  final seen = <String>{};
  for (final memory in memories) {
    final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
    if (coords == null) continue;
    final key = latLngCacheKey(coords.lat, coords.lng);
    if (!seen.add(key)) continue;
    if (cache.containsKey(key) && cache[key]!.trim().isNotEmpty) continue;

    final address = await PlaceLookupService.resolveFullAddress(
      coords.lat,
      coords.lng,
      localeCode: localeCode,
    );
    if (address != null && address.trim().isNotEmpty) {
      cache[key] = address.trim();
      changed = true;
    }
  }

  if (changed) await saveMemoryPlaceFullAddresses(prefs, cache);
  return cache;
}

String? _addressFromMemoryCoords(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  String localeCode = 'ko',
}) {
  return _addressFromDisplayCoords(
    memory,
    placeCache,
    fullAddressCache,
    localeCode: localeCode,
  );
}

/// 카드·상세용 상세 주소 — GPS 역지오코딩 우선, 없으면 장소 엔티티·짧은 장소명.
String displayPlaceAddress(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  required String localeCode,
  List<Memory>? allMemories,
}) {
  if (isGraphNoteMemory(memory)) {
    return _displayPlaceAddressForGraphNote(
      memory,
      placeCache,
      fullAddressCache,
      localeCode: localeCode,
      allMemories: allMemories,
    );
  }

  final pinned = pinnedPlaceLabelForMemory(memory, localeCode: localeCode);
  if (pinned != null && pinned.isNotEmpty) return pinned;

  final fromCoords = _addressFromMemoryCoords(
    memory,
    placeCache,
    fullAddressCache,
    localeCode: localeCode,
  );
  if (fromCoords != null) return fromCoords;

  final fromEntity = placeLabelFromEntities(memory);
  if (fromEntity != null) return fromEntity;

  final summary = memory.summary.trim();
  if (summary.contains('·')) {
    final first = summary.split('·').map((e) => e.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    if (first.isNotEmpty && !isLatLngLabel(first) && !isLikelyLotNumber(first)) {
      return first;
    }
  }

  return _unknownPlaceLabel(localeCode);
}

String _displayPlaceAddressForGraphNote(
  Memory memory,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  required String localeCode,
  List<Memory>? allMemories,
}) {
  final fromCoords = _addressFromMemoryCoords(
    memory,
    placeCache,
    fullAddressCache,
    localeCode: localeCode,
  );
  if (fromCoords != null) return fromCoords;

  final pinned = pinnedPlaceLabelForMemory(memory, localeCode: localeCode);
  if (pinned != null && pinned.isNotEmpty) return pinned;

  final fromEntity = placeLabelFromEntities(memory);
  if (fromEntity != null) return fromEntity;

  if (allMemories != null) {
    final primary = allMemories.where((m) => !isGraphNoteMemory(m)).toList();
    final related = resolveGraphNoteRelatedMemory(memory, primary);
    if (related != null) {
      final relatedAddress = displayPlaceAddress(
        related,
        placeCache,
        fullAddressCache,
        localeCode: localeCode,
        allMemories: allMemories,
      );
      if (relatedAddress != _unknownPlaceLabel(localeCode)) return relatedAddress;
    }
  }

  return _unknownPlaceLabel(localeCode);
}

String displayGroupAddress(
  MemoryTimelineGroup group,
  Map<String, String> placeCache,
  Map<String, String> fullAddressCache, {
  required String localeCode,
  List<Memory>? allMemories,
}) {
  for (final memory in group.memories) {
    final address = displayPlaceAddress(
      memory,
      placeCache,
      fullAddressCache,
      localeCode: localeCode,
      allMemories: allMemories,
    );
    if (address != _unknownPlaceLabel(localeCode)) return address;
  }
  return displayPlaceAddress(
    group.primary,
    placeCache,
    fullAddressCache,
    localeCode: localeCode,
    allMemories: allMemories,
  );
}

/// 카드·그래프 제목: 좌표 대신 장소명, 좌표 문자열은 숨깁니다.
String displayPlaceTitle(
  Memory memory,
  Map<String, String> placeCache, {
  required String localeCode,
  List<Memory>? allMemories,
}) {
  if (isGraphNoteMemory(memory)) {
    return _displayPlaceTitleForGraphNote(
      memory,
      placeCache,
      localeCode: localeCode,
      allMemories: allMemories,
    );
  }

  final pinned = pinnedPlaceLabelForMemory(memory, localeCode: localeCode);
  if (pinned != null && pinned.isNotEmpty) return pinned;

  final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
  if (coords != null) {
    final cached = _placeNameFromCoords(coords, placeCache);
    if (cached != null && cached.isNotEmpty) return cached;
  }

  final fromEntity = placeLabelFromEntities(memory);
  if (fromEntity != null) return fromEntity;

  // 사진 메타(장소·인물·시간) 형식 summary만 장소로 사용 — 음성·텍스트 한 줄 요약은 제외.
  final summary = memory.summary.trim();
  if (summary.contains('·')) {
    final first = summary.split('·').map((e) => e.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    if (first.isNotEmpty && !isLatLngLabel(first) && !isLikelyLotNumber(first)) {
      return first;
    }
  }

  return _unknownPlaceLabel(localeCode);
}

String _unknownPlaceLabel(String localeCode) =>
    localeCode == 'ko' ? '장소 미상' : 'Unknown place';

String _displayPlaceTitleForGraphNote(
  Memory memory,
  Map<String, String> placeCache, {
  required String localeCode,
  List<Memory>? allMemories,
}) {
  final pinned = pinnedPlaceLabelForMemory(memory, localeCode: localeCode);
  if (pinned != null && pinned.isNotEmpty) return pinned;

  final coords = displayCoordinatesForMemory(memory, localeCode: localeCode);
  if (coords != null) {
    final cached = _placeNameFromCoords(coords, placeCache);
    if (cached != null && cached.isNotEmpty) return cached;
  }

  final fromEntity = placeLabelFromEntities(memory);
  if (fromEntity != null) return fromEntity;

  if (allMemories != null) {
    final primary = allMemories.where((m) => !isGraphNoteMemory(m)).toList();
    final related = resolveGraphNoteRelatedMemory(memory, primary);
    if (related != null) {
      final relatedPlace = displayPlaceTitle(
        related,
        placeCache,
        localeCode: localeCode,
        allMemories: allMemories,
      );
      if (relatedPlace != _unknownPlaceLabel(localeCode)) return relatedPlace;
    }
  }

  return _unknownPlaceLabel(localeCode);
}

String displayGroupTitle(
  MemoryTimelineGroup group,
  Map<String, String> placeCache, {
  required String localeCode,
  List<Memory>? allMemories,
}) {
  for (final memory in group.memories) {
    if (!isGraphNoteMemory(memory)) {
      final title = displayPlaceTitle(
        memory,
        placeCache,
        localeCode: localeCode,
        allMemories: allMemories,
      );
      if (title != _unknownPlaceLabel(localeCode)) return title;
    }
  }
  return displayPlaceTitle(
    group.primary,
    placeCache,
    localeCode: localeCode,
    allMemories: allMemories,
  );
}

String stripLatLngFromTitle(String title) {
  final parts = title
      .split('·')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && !isLatLngLabel(e))
      .toList();
  return parts.join(' · ');
}
