import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

const String prefFcmToken = 'fcm_device_token';

/// FCM 수신 → 로컬 알림 표시 (회상·펄스 페이로드 호환).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {}
  await NotificationService.instance.initialize();
  await FcmPushService.instance.presentRemoteMessage(message);
}

/// Firebase Cloud Messaging — 원격 푸시를 로컬 알림 채널로 전달합니다.
/// 장소 회상은 WorkManager+로컬 알림이 주경로이며, FCM은 서버 푸시·동기화 보조입니다.
class FcmPushService {
  FcmPushService._();
  static final FcmPushService instance = FcmPushService._();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _started = false;

  Future<void> start({SharedPreferences? prefs}) async {
    if (kIsWeb || _started) return;
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM: Firebase not initialized — skip');
      return;
    }
    _started = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _foregroundSub = FirebaseMessaging.onMessage.listen(presentRemoteMessage);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleOpen(initial);
    }

    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM token acquired (${token.length} chars)');
        final p = prefs ?? await SharedPreferences.getInstance();
        await p.setString(prefFcmToken, token);
      }
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }

    messaging.onTokenRefresh.listen((token) async {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(prefFcmToken, token);
    });
  }

  Future<void> presentRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = (notification?.title ?? data['title'] ?? '').toString().trim();
    final body = (notification?.body ?? data['body'] ?? '').toString().trim();
    if (title.isEmpty && body.isEmpty) return;

    final memoryId = (data['memoryId'] ?? data['memory_id'] ?? '').toString().trim();
    final pulse = (data['pulse'] ?? '').toString().trim();
    final payload = pulse.isNotEmpty
        ? 'pulse:$pulse'
        : (memoryId.isNotEmpty ? memoryId : jsonEncode(data));

    final locale = data['locale']?.toString() ?? 'ko';
    final id = message.hashCode & 0x7fffffff;
    if (pulse.isNotEmpty || data['type'] == 'pulse') {
      await NotificationService.instance.showPulse(
        id: id == 0 ? 10002 : id,
        title: title.isEmpty ? (locale == 'ko' ? '모담넷 · 오늘의 기억' : 'MemoryOS · Today') : title,
        body: body.isEmpty ? (locale == 'ko' ? '잠깐, 오늘 떠오른 기억이 있어요' : 'A memory from today is waiting') : body,
        payload: payload,
        localeCode: locale,
      );
    } else {
      await NotificationService.instance.showRecall(
        id: id == 0 ? 42 : id,
        title: title.isEmpty ? (locale == 'ko' ? '모담넷' : 'MemoryOS') : title,
        body: body.isEmpty ? (locale == 'ko' ? '새 알림이 있어요' : 'You have a new notification') : body,
        memoryId: memoryId.isEmpty ? payload : memoryId,
        localeCode: locale,
      );
    }
  }

  void _handleOpen(RemoteMessage message) {
    final data = message.data;
    final memoryId = (data['memoryId'] ?? data['memory_id'] ?? '').toString().trim();
    final pulse = (data['pulse'] ?? '').toString().trim();
    final payload = pulse.isNotEmpty
        ? 'pulse:$pulse'
        : memoryId;
    if (payload.isNotEmpty) {
      NotificationService.instance.onNotificationTapped?.call(payload);
    }
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
    _started = false;
  }

  static String? readStoredToken(SharedPreferences prefs) => prefs.getString(prefFcmToken);
}
