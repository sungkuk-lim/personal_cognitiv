import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import '../utils/ocr_utils.dart';

/// GPS 좌표를 장소명(도로·지역·시설)으로 변환합니다.
class PlaceLookupService {
  PlaceLookupService._();

  static Future<String?> resolvePlaceName(
    double latitude,
    double longitude, {
    String localeCode = 'ko',
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      return _labelFromPlacemark(placemarks.first);
    } catch (e, stack) {
      debugPrint('Reverse geocode failed: $e\n$stack');
      return null;
    }
  }

  static Future<String?> resolveFullAddress(
    double latitude,
    double longitude, {
    String localeCode = 'ko',
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      String? best;
      var bestScore = -1;
      for (final p in placemarks) {
        final formatted = formatFullAddress(p);
        if (formatted == null || formatted.trim().isEmpty) continue;
        final score = _addressQualityScore(formatted);
        if (score > bestScore) {
          bestScore = score;
          best = formatted;
        }
      }
      return best;
    } catch (e, stack) {
      debugPrint('Reverse geocode full address failed: $e\n$stack');
      return null;
    }
  }

  static final RegExp _bareNumberPattern = RegExp(r'^\d{1,5}(?:-\d{1,5})*$');
  static final RegExp _koreanRoadToken = RegExp(
    r'([가-힣A-Za-z0-9]+(?:로|길|대로))(?:\s+(\d{1,5}(?:-\d{1,5})*))?',
  );

  /// 도로명(로·길·대로) 없이 시·도 + 번지만 있는 주소 — 상세 주소로 부족함.
  static bool isAddressMissingRoadName(String address) {
    final v = address.trim();
    if (v.isEmpty) return true;
    if (RegExp(r'(?:로|길|대로)').hasMatch(v)) return false;
    if (RegExp(r'\d{1,5}(?:-\d{1,5})?$').hasMatch(v)) return true;
    return false;
  }

  static String? formatFullAddress(Placemark p) {
    final streetLine = p.street?.trim() ?? '';
    if (streetLine.isNotEmpty && _koreanRoadToken.hasMatch(streetLine)) {
      final normalized = streetLine.replaceAll(RegExp(r'\s+'), ' ');
      if (!isAddressMissingRoadName(normalized)) return normalized;
    }

    final region = p.administrativeArea?.trim() ?? '';
    final city = p.locality?.trim() ?? '';
    final district = p.subAdministrativeArea?.trim() ?? '';
    final neighborhood = p.subLocality?.trim() ?? '';
    final number = p.subThoroughfare?.trim() ?? '';

    final parts = <String>[];
    void addPart(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return;
      if (parts.any((e) => e == v || e.contains(v) || v.contains(e))) return;
      parts.add(v);
    }

    addPart(region);
    if (city != region) addPart(city);
    if (district != city && district != region) addPart(district);
    if (neighborhood != city && neighborhood != district && neighborhood != region) {
      addPart(neighborhood);
    }

    final roadLine = _roadLineFromPlacemark(p);
    if (roadLine != null) {
      addPart(roadLine);
    } else if (number.isNotEmpty) {
      // 번지는 있으나 도로명(로·길·대로)을 찾지 못함 — 불완전 주소를 만들지 않음.
      return null;
    }

    if (parts.isEmpty) {
      final fallback = _labelFromPlacemark(p);
      return fallback?.isNotEmpty == true ? fallback : null;
    }

    final joined = parts.join(' ');
    if (isAddressMissingRoadName(joined)) return null;
    return joined;
  }

  /// 도로명 + 번지(예: 한화2길 33-21) 한 줄 추출.
  static String? _roadLineFromPlacemark(Placemark p) {
    final number = p.subThoroughfare?.trim() ?? '';
    final thoroughfare = p.thoroughfare?.trim() ?? '';

    if (thoroughfare.isNotEmpty) {
      if (_looksLikeKoreanRoadName(thoroughfare)) {
        if (number.isNotEmpty && !thoroughfare.contains(number)) {
          return '$thoroughfare $number';
        }
        return thoroughfare;
      }
    }

    for (final raw in [p.street, p.name, p.thoroughfare]) {
      final text = raw?.trim() ?? '';
      if (text.isEmpty) continue;
      final match = _koreanRoadToken.firstMatch(text);
      if (match != null) {
        final road = match.group(1)!;
        final inlineNum = match.group(2)?.trim() ?? '';
        if (inlineNum.isNotEmpty) return '$road $inlineNum';
        if (number.isNotEmpty) return '$road $number';
        return road;
      }
    }

    return null;
  }

  static bool _looksLikeKoreanRoadName(String value) {
    return RegExp(r'(?:로|길|대로)$').hasMatch(value.trim());
  }

  static int _addressQualityScore(String address) {
    var score = address.length;
    if (!isAddressMissingRoadName(address)) score += 200;
    if (RegExp(r'(?:로|길|대로)').hasMatch(address)) score += 80;
    return score;
  }

  static Future<({double lat, double lng})?> resolveCoordinatesForPlace(
    String placeLabel, {
    String localeCode = 'ko',
  }) async {
    final query = placeLabel.trim();
    if (query.length < 2) return null;
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return null;
      final first = locations.first;
      return (lat: first.latitude, lng: first.longitude);
    } catch (e, stack) {
      debugPrint('Forward geocode failed for "$query": $e\n$stack');
      return null;
    }
  }

  static String? _labelFromPlacemark(Placemark p) {
    final candidates = <String>[
      if (p.thoroughfare != null && p.thoroughfare!.trim().isNotEmpty) p.thoroughfare!.trim(),
      if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) p.subLocality!.trim(),
      if (p.locality != null && p.locality!.trim().isNotEmpty) p.locality!.trim(),
      if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty)
        p.subAdministrativeArea!.trim(),
      if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty)
        p.administrativeArea!.trim(),
      if (p.name != null && p.name!.trim().isNotEmpty) p.name!.trim(),
    ];

    final seen = <String>{};
    for (final c in candidates) {
      final normalized = c.replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.length < 2) continue;
      if (RegExp(r'^\d{1,5}(?:-\d{1,5})+$').hasMatch(normalized)) continue;
      if (seen.add(normalized)) return normalized;
    }
    return null;
  }

  /// 촬영·기억 확인용 — 상세 주소 우선, 없으면 짧은 장소명.
  static Future<String?> resolveCapturePlaceLabel(
    double latitude,
    double longitude, {
    String localeCode = 'ko',
  }) async {
    final full = await resolveFullAddress(latitude, longitude, localeCode: localeCode);
    if (full != null && full.trim().isNotEmpty && !_isWeakCaptureLabel(full)) {
      return full.trim();
    }
    final short = await resolvePlaceName(latitude, longitude, localeCode: localeCode);
    if (short != null && short.trim().isNotEmpty && !_isWeakCaptureLabel(short)) {
      return short.trim();
    }
    return full?.trim().isNotEmpty == true ? full!.trim() : short?.trim();
  }

  static bool _isWeakCaptureLabel(String label) {
    final v = label.trim();
    if (v.isEmpty) return true;
    if (isLikelyLotNumber(v)) return true;
    if (RegExp(r'^\d{1,5}(?:-\d{1,5})+\s*$').hasMatch(v)) return true;
    if (isAddressMissingRoadName(v)) return true;
    // 동·읍·면만 단독(예: 금곡동) — 상세 주소로 보기 어려움.
    if (v.length <= 6 && RegExp(r'[동읍면]$').hasMatch(v) && !v.contains(' ')) return true;
    return false;
  }
}
