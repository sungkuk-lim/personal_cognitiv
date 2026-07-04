import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../models/memory.dart';
import '../utils/recall_anchor.dart';
import '../utils/semantic_search.dart';
import 'background_recall_worker.dart';
import 'location_permission_service.dart';
import 'notification_service.dart';

const String _prefRecallCooldown = 'recall_cooldown_until';
const double _recallRadiusMeters = 250;

class ProactiveRecallService with WidgetsBindingObserver {
  ProactiveRecallService(this._prefs);
  final SharedPreferences _prefs;
  Timer? _timer;
  List<Memory> _memories = const [];
  bool _checking = false;

  void updateMemories(List<Memory> memories) {
    _memories = memories;
    BackgroundRecallWorker.saveMemorySnapshot(_prefs, memories);
  }

  void start() {
    if (!readProactiveRecallEnabled(_prefs)) return;
    WidgetsBinding.instance.addObserver(this);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => checkNow());
    Future<void>.delayed(const Duration(seconds: 2), checkNow);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!readProactiveRecallEnabled(_prefs)) return;
    if (state == AppLifecycleState.resumed) {
      checkNow();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      BackgroundRecallWorker.saveMemorySnapshot(_prefs, _memories);
      BackgroundRecallWorker.scheduleImmediateCheck();
    }
  }

  Future<void> checkNow({bool background = false}) async {
    if (_checking || _memories.isEmpty || !readProactiveRecallEnabled(_prefs)) return;
    final cooldown = _prefs.getInt(_prefRecallCooldown) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < cooldown) return;

    _checking = true;
    try {
      final position = background
          ? await LocationPermissionService.getPositionForRecallInBackground()
          : await LocationPermissionService.getCurrentPositionIfAllowed();
      if (position == null) return;

      Memory? nearest;
      var nearestDistance = double.infinity;
      for (final memory in _memories) {
        final coords = effectiveRecallCoordinates(memory);
        if (coords == null) continue;
        final d = _distanceMeters(
          position.latitude,
          position.longitude,
          coords.lat,
          coords.lng,
        );
        if (d <= _recallRadiusMeters && d < nearestDistance) {
          nearest = memory;
          nearestDistance = d;
        }
      }

      if (nearest == null) return;

      final localeCode = readLanguageCode(_prefs);
      final body = nearest.summary.isNotEmpty ? nearest.summary : nearest.content;
      await NotificationService.instance.showRecall(
        id: nearest.id.hashCode,
        title: recallNotificationTitle(localeCode),
        body: body.length > 120 ? '${body.substring(0, 117)}...' : body,
        memoryId: nearest.id,
        localeCode: localeCode,
      );
      await _prefs.setInt(
        _prefRecallCooldown,
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Proactive recall error: $e');
    } finally {
      _checking = false;
    }
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;
}
