import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum AppLocationAccess {
  /// 백그라운드 회상 포함 「항상 허용」.
  always,
  /// 앱 사용 중만.
  whileInUse,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationPermissionService {
  LocationPermissionService._();

  static Future<AppLocationAccess> currentAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return AppLocationAccess.serviceDisabled;
    }
    return _fromPermission(await Geolocator.checkPermission());
  }

  static Future<AppLocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return AppLocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _fromPermission(permission);
  }

  static bool hasForegroundAccess(AppLocationAccess access) =>
      access == AppLocationAccess.always || access == AppLocationAccess.whileInUse;

  static Future<Position?> getCurrentPositionForMemoryCapture() async {
    try {
      final access = await currentAccess();
      if (!hasForegroundAccess(access)) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (e, stack) {
      debugPrint('getCurrentPositionForMemoryCapture failed: $e\n$stack');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<Position?> getCurrentPositionIfAllowed() async {
    try {
      final access = await currentAccess();
      if (!hasForegroundAccess(access)) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (e, stack) {
      debugPrint('getCurrentPositionIfAllowed failed: $e\n$stack');
      return null;
    }
  }

  /// 앱 종료·백그라운드 Workmanager용 — 최근 위치 + (always 권한 시) 저전력 GPS.
  static Future<Position?> getPositionForRecallInBackground() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? last;
      try {
        last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final age = DateTime.now().difference(last.timestamp);
          if (age.inHours <= 6) return last;
        }
      } catch (_) {}

      if (permission == LocationPermission.always) {
        try {
          return await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20),
            ),
          );
        } catch (_) {}
      }

      return last ?? await Geolocator.getLastKnownPosition();
    } catch (e, stack) {
      debugPrint('getPositionForRecallInBackground failed: $e\n$stack');
      return null;
    }
  }

  /// 회상 알림 ON 시 Android 백그라운드 위치(항상 허용) 요청.
  static Future<bool> requestBackgroundLocationForRecall() async {
    if (!Platform.isAndroid) return true;

    final access = await requestAccess();
    if (!hasForegroundAccess(access)) return false;

    final status = await ph.Permission.locationAlways.status;
    if (status.isGranted) return true;

    final result = await ph.Permission.locationAlways.request();
    return result.isGranted;
  }

  static Future<bool> hasBackgroundLocationForRecall() async {
    if (!Platform.isAndroid) return true;
    return ph.Permission.locationAlways.isGranted;
  }

  static Future<bool> openAppSettings() => ph.openAppSettings();

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static AppLocationAccess _fromPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return AppLocationAccess.always;
      case LocationPermission.whileInUse:
        return AppLocationAccess.whileInUse;
      case LocationPermission.deniedForever:
        return AppLocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return AppLocationAccess.denied;
    }
  }
}
