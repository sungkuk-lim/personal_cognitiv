import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

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
      return formatFullAddress(placemarks.first);
    } catch (e, stack) {
      debugPrint('Reverse geocode full address failed: $e\n$stack');
      return null;
    }
  }

  static String? formatFullAddress(Placemark p) {
    final region = p.administrativeArea?.trim() ?? '';
    final city = p.locality?.trim() ?? '';
    final street = p.thoroughfare?.trim() ?? '';
    final number = p.subThoroughfare?.trim() ?? '';

    final parts = <String>[];
    if (region.isNotEmpty) parts.add(region);
    if (city.isNotEmpty && city != region) parts.add(city);

    if (street.isNotEmpty && number.isNotEmpty) {
      parts.add('$street $number');
    } else if (street.isNotEmpty) {
      parts.add(street);
    } else if (number.isNotEmpty) {
      parts.add(number);
    }

    if (parts.isEmpty) {
      final fallback = _labelFromPlacemark(p);
      return fallback?.isNotEmpty == true ? fallback : null;
    }
    return parts.join(' ');
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
      if (p.name != null && p.name!.trim().isNotEmpty) p.name!.trim(),
      if (p.thoroughfare != null && p.thoroughfare!.trim().isNotEmpty) p.thoroughfare!.trim(),
      if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) p.subLocality!.trim(),
      if (p.locality != null && p.locality!.trim().isNotEmpty) p.locality!.trim(),
      if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty)
        p.subAdministrativeArea!.trim(),
      if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty)
        p.administrativeArea!.trim(),
    ];

    final seen = <String>{};
    for (final c in candidates) {
      final normalized = c.replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.length < 2) continue;
      if (seen.add(normalized)) return normalized;
    }
    return null;
  }
}
