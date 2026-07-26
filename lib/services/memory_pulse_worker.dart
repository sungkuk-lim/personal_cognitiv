import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../core/prefs.dart';
import '../models/memory.dart';
import '../services/local_memory_store.dart';
import '../services/memory_pulse_service.dart';
import 'notification_service.dart';

const String prefPulseMemorySnapshot = 'pulse_memory_snapshot';
const String memoryPulseTaskName = 'memoryPulseDaily';

/// 매일 아침 기억 펄스 알림 (로컬).
class MemoryPulseWorker {
  static const String uniqueName = 'memoryos_pulse_daily';

  static Future<void> register() async {
    if (!readMemoryPulseEnabled(await SharedPreferences.getInstance())) return;
    await Workmanager().registerPeriodicTask(
      uniqueName,
      memoryPulseTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.not_required),
      existingWorkPolicy: ExistingWorkPolicy.update,
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(uniqueName);
    await NotificationService.instance.cancelDailyPulseSchedule();
  }

  /// OS 예약 알림 — 앱이 꺼져 있어도 아침에 펄스를 시도합니다.
  static Future<void> ensureScheduled(SharedPreferences prefs) async {
    if (!readMemoryPulseEnabled(prefs)) {
      await NotificationService.instance.cancelDailyPulseSchedule();
      return;
    }
    final locale = readLanguageCode(prefs);
    final location = tz.getLocation(locale == 'ko' ? 'Asia/Seoul' : 'UTC');
    final now = tz.TZDateTime.now(location);
    var next = tz.TZDateTime(location, now.year, now.month, now.day, 8, 5);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final memories = _loadSnapshotMemories(prefs);
    final offer = buildDailyMemoryPulse(memories, localeCode: locale);
    await NotificationService.instance.scheduleDailyPulse(
      scheduledDate: next,
      localeCode: locale,
      title: offer?.title,
      body: offer?.subtitle,
    );
  }

  static List<Memory> _loadSnapshotMemories(SharedPreferences prefs) {
    final raw = prefs.getString(prefPulseMemorySnapshot);
    if (raw == null || raw.isEmpty) {
      return LocalMemoryStore(prefs).loadAll();
    }
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Memory.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveMemorySnapshot(SharedPreferences prefs, List<Memory> memories) async {
    final snapshot = memories.map((m) => m.toLocalJson()).toList();
    await prefs.setString(prefPulseMemorySnapshot, jsonEncode(snapshot));
  }

  /// 앱 실행 중 오늘 펄스가 아직 없으면 즉시 시도합니다.
  static Future<void> maybeDeliverInForeground(SharedPreferences prefs, List<Memory> memories) async {
    if (!readMemoryPulseEnabled(prefs)) return;
    final todayKey = _todayKey();
    if (readLastPulseDate(prefs) == todayKey) return;
    final locale = readLanguageCode(prefs);
    final offer = buildDailyMemoryPulse(memories, localeCode: locale);
    if (offer == null) return;
    await NotificationService.instance.showPulse(
      id: offer.hashCode,
      title: offer.title,
      body: offer.subtitle,
      payload: offer.notificationPayload(),
      localeCode: locale,
    );
    await writeLastPulseDate(prefs, todayKey);
  }
}

String _todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}
