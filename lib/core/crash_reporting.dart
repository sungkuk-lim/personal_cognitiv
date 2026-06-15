import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'env.dart';

/// Flutter 에러 + Firebase Crashlytics (무료) 연동.
class CrashReporting {
  CrashReporting._();

  static bool _firebaseReady = false;
  static final List<String> _recentErrors = [];
  static const int maxStored = 20;

  static bool get isFirebaseReady => _firebaseReady;
  static List<String> get recentErrors => List.unmodifiable(_recentErrors);

  static bool get _hasValidFirebaseConfig {
    final options = DefaultFirebaseOptions.android;
    return !options.apiKey.contains('Placeholder') && !options.appId.contains('000000000000');
  }

  static Future<void> install() async {
    if (AppEnv.enableCrashlytics && _hasValidFirebaseConfig) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
        _firebaseReady = true;
        debugPrint('Crashlytics: Firebase initialized');
      } catch (e, stack) {
        debugPrint('Firebase init skipped: $e\n$stack');
      }
    } else if (AppEnv.enableCrashlytics) {
      debugPrint('Crashlytics: placeholder config — run scripts/setup_firebase.ps1');
    }

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_firebaseReady) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      _record('FlutterError', details.exceptionAsString());
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
      previousFlutterHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_firebaseReady) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      _record('PlatformError', '$error\n$stack');
      return true;
    };
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    _record(reason ?? 'Error', error.toString());
    if (_firebaseReady) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
      );
    }
  }

  static void log(String message) {
    _record('Log', message);
    if (_firebaseReady) {
      FirebaseCrashlytics.instance.log(message);
    }
  }

  static void _record(String type, String message) {
    final entry = '[$type] ${DateTime.now().toIso8601String()}: $message';
    debugPrint('CrashReporting: $entry');
    _recentErrors.insert(0, entry);
    if (_recentErrors.length > maxStored) {
      _recentErrors.removeRange(maxStored, _recentErrors.length);
    }
  }
}
