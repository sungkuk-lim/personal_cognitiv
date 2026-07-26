import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 알림 탭 시 payload 전달 (memoryId 또는 pulse:...).
  void Function(String payload)? onNotificationTapped;

  /// @deprecated use onNotificationTapped
  set onRecallTapped(void Function(String memoryId)? handler) {
    onNotificationTapped = handler == null ? null : (payload) {
      if (!payload.startsWith('pulse:')) handler(payload);
    };
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTapped?.call(payload);
        }
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<void> showRecall({
    required int id,
    required String title,
    required String body,
    required String memoryId,
    String localeCode = 'ko',
  }) async {
    if (!_initialized) await initialize();
    final channelName = localeCode == 'ko' ? '기억 소환' : 'Memory recall';
    final channelDesc = localeCode == 'ko'
        ? '과거 장소에서 기억을 알려줍니다'
        : 'Reminds you of memories at places you visit';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'memory_recall',
        channelName,
        channelDescription: channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: memoryId);
  }

  static const int dailyPulseNotificationId = 10001;

  Future<void> scheduleDailyPulse({
    required tz.TZDateTime scheduledDate,
    String localeCode = 'ko',
    String? title,
    String? body,
  }) async {
    if (!_initialized) await initialize();
    final channelName = localeCode == 'ko' ? '기억 펄스' : 'Memory pulse';
    final channelDesc = localeCode == 'ko'
        ? 'N년 전 오늘·인물 하이라이트를 알려줍니다'
        : 'On-this-day memories and person highlights';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'memory_pulse',
        channelName,
        channelDescription: channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    final resolvedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : (localeCode == 'ko' ? '모담넷 · 오늘의 기억' : 'MemoryOS · Today');
    final resolvedBody = body?.trim().isNotEmpty == true
        ? body!.trim()
        : (localeCode == 'ko' ? '잠깐, 오늘 떠오른 기억이 있어요' : 'A memory from today is waiting');

    // USE_EXACT_ALARM is not allowed for non alarm/calendar apps.
    // Prefer SCHEDULE_EXACT_ALARM when the user grants it; otherwise inexact.
    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidPlugin?.canScheduleExactNotifications();
      if (canExact == true) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      } else {
        await androidPlugin?.requestExactAlarmsPermission();
        final granted = await androidPlugin?.canScheduleExactNotifications();
        if (granted == true) {
          mode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      }
    }

    await _plugin.zonedSchedule(
      dailyPulseNotificationId,
      resolvedTitle,
      resolvedBody,
      scheduledDate,
      details,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'pulse:scheduled',
    );
  }

  Future<void> cancelDailyPulseSchedule() async {
    await _plugin.cancel(dailyPulseNotificationId);
  }

  Future<void> showPulse({
    required int id,
    required String title,
    required String body,
    required String payload,
    String localeCode = 'ko',
  }) async {
    if (!_initialized) await initialize();
    final channelName = localeCode == 'ko' ? '기억 펄스' : 'Memory pulse';
    final channelDesc = localeCode == 'ko'
        ? 'N년 전 오늘·인물 하이라이트를 알려줍니다'
        : 'On-this-day memories and person highlights';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'memory_pulse',
        channelName,
        channelDescription: channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
