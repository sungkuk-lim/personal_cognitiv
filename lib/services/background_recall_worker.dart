import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/memory.dart';
import 'notification_service.dart';
import 'proactive_recall_service.dart';

const String recallBackgroundTaskName = 'proactiveRecallCheck';
const String prefRecallMemorySnapshot = 'recall_memory_snapshot';

/// 백그라운드에서도 위치 기반 회상을 체크합니다 (Android, 최소 15분 주기).
class BackgroundRecallWorker {
  static const String uniqueName = 'memoryos_recall_periodic';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  }

  static Future<void> register() async {
    await Workmanager().registerPeriodicTask(
      uniqueName,
      recallBackgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(uniqueName);
  }

  static Future<void> saveMemorySnapshot(SharedPreferences prefs, List<Memory> memories) async {
    final snapshot = memories
        .where((m) => m.lat != null && m.lng != null)
        .map((m) => {
              'id': m.id,
              'summary': m.summary,
              'content': m.content,
              'lat': m.lat,
              'lng': m.lng,
            })
        .toList();
    await prefs.setString(prefRecallMemorySnapshot, jsonEncode(snapshot));
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != recallBackgroundTaskName) return true;

    try {
      await NotificationService.instance.initialize();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefRecallMemorySnapshot);
      if (raw == null || raw.isEmpty) return true;

      final list = (jsonDecode(raw) as List<dynamic>).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return Memory(
          id: m['id'].toString(),
          content: m['content'] as String? ?? '',
          summary: m['summary'] as String? ?? '',
          entities: const [],
          createdAt: DateTime.now(),
          lat: (m['lat'] as num?)?.toDouble(),
          lng: (m['lng'] as num?)?.toDouble(),
        );
      }).toList();

      final service = ProactiveRecallService(prefs);
      service.updateMemories(list);
      await service.checkNow();
    } catch (e) {
      debugPrint('Background recall error: $e');
    }
    return true;
  });
}
