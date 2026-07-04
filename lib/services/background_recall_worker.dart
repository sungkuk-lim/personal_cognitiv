import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/prefs.dart';
import '../models/memory.dart';
import '../utils/recall_anchor.dart';
import 'local_memory_store.dart';
import 'memory_pulse_service.dart';
import 'memory_pulse_worker.dart' show MemoryPulseWorker, memoryPulseTaskName, prefPulseMemorySnapshot;
import 'notification_service.dart';
import 'proactive_recall_service.dart';
import 'recall_background_plugins.dart';

const String recallBackgroundTaskName = 'proactiveRecallCheck';
const String prefRecallMemorySnapshot = 'recall_memory_snapshot';

/// 백그라운드 회상·기억 펄스 (Android Workmanager).
class BackgroundRecallWorker {
  static const String uniqueName = 'memoryos_recall_periodic';
  static const String oneOffName = 'memoryos_recall_once';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  }

  static Future<void> register() async {
    await Workmanager().registerPeriodicTask(
      uniqueName,
      recallBackgroundTaskName,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.update,
    );
    await MemoryPulseWorker.register();
  }

  static Future<void> scheduleImmediateCheck() async {
    await Workmanager().registerOneOffTask(
      oneOffName,
      recallBackgroundTaskName,
      initialDelay: const Duration(minutes: 1),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(uniqueName);
    await Workmanager().cancelByUniqueName(oneOffName);
  }

  static Future<void> cancelAll() async {
    await cancel();
    await MemoryPulseWorker.cancel();
  }

  static Future<void> saveMemorySnapshot(SharedPreferences prefs, List<Memory> memories) async {
    final snapshot = memories
        .map((m) {
          final coords = effectiveRecallCoordinates(m);
          if (coords == null) return null;
          return {
            'id': m.id,
            'summary': m.summary,
            'content': m.content,
            'lat': coords.lat,
            'lng': coords.lng,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    await prefs.setString(prefRecallMemorySnapshot, jsonEncode(snapshot));
    await MemoryPulseWorker.saveMemorySnapshot(prefs, memories);
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == memoryPulseTaskName) {
      return _runMemoryPulseTask();
    }
    if (task != recallBackgroundTaskName) return true;

    try {
      await ensureRecallBackgroundPlugins();
      await NotificationService.instance.initialize();
      final prefs = await SharedPreferences.getInstance();
      if (!readProactiveRecallEnabled(prefs)) return true;
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
      await service.checkNow(background: true);
    } catch (e, stack) {
      debugPrint('Background recall error: $e\n$stack');
    }
    return true;
  });
}

Future<bool> _runMemoryPulseTask() async {
  try {
    await ensureRecallBackgroundPlugins();
    await NotificationService.instance.initialize();
    final prefs = await SharedPreferences.getInstance();
    if (!readMemoryPulseEnabled(prefs)) return true;
    final todayKey = _pulseTodayKey();
    if (readLastPulseDate(prefs) == todayKey) return true;

    final raw = prefs.getString(prefPulseMemorySnapshot);
    final memories = raw != null && raw.isNotEmpty
        ? (jsonDecode(raw) as List<dynamic>)
            .map((e) => Memory.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : LocalMemoryStore(prefs).loadAll();

    final locale = readLanguageCode(prefs);
    final offer = buildDailyMemoryPulse(memories, localeCode: locale);
    if (offer == null) return true;

    await NotificationService.instance.showPulse(
      id: offer.hashCode,
      title: offer.title,
      body: offer.subtitle,
      payload: offer.notificationPayload(),
      localeCode: locale,
    );
    await writeLastPulseDate(prefs, todayKey);
  } catch (e, stack) {
    debugPrint('Memory pulse error: $e\n$stack');
  }
  return true;
}

String _pulseTodayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
