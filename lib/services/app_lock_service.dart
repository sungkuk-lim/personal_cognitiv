import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefAppLockBiometric = 'app_lock_biometric';
const String prefAppLockPattern = 'app_lock_pattern';
const String prefAppLockSetupDone = 'app_lock_setup_prompted';

/// 기기 잠금 — 지문(생체) · 패턴. 클라우드 계정과 별개로 기기에서만 동작합니다.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static const _patternKey = 'modamnet_pattern_hash_v1';

  bool readBiometricEnabled(SharedPreferences prefs) =>
      prefs.getBool(prefAppLockBiometric) ?? false;

  Future<void> writeBiometricEnabled(SharedPreferences prefs, bool enabled) async {
    await prefs.setBool(prefAppLockBiometric, enabled);
  }

  bool readPatternEnabled(SharedPreferences prefs) =>
      prefs.getBool(prefAppLockPattern) ?? false;

  Future<void> writePatternEnabled(SharedPreferences prefs, bool enabled) async {
    await prefs.setBool(prefAppLockPattern, enabled);
  }

  bool readSetupPrompted(SharedPreferences prefs) =>
      prefs.getBool(prefAppLockSetupDone) ?? false;

  Future<void> writeSetupPrompted(SharedPreferences prefs, bool done) async {
    await prefs.setBool(prefAppLockSetupDone, done);
  }

  Future<bool> hasPattern() async {
    final hash = await _secure.read(key: _patternKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> savePattern(List<int> dots) async {
    if (dots.length < 4) {
      throw ArgumentError('패턴은 최소 4개 점을 연결해야 합니다.');
    }
    await _secure.write(key: _patternKey, value: _hashPattern(dots));
  }

  Future<bool> verifyPattern(List<int> dots) async {
    final stored = await _secure.read(key: _patternKey);
    if (stored == null || stored.isEmpty) return false;
    return stored == _hashPattern(dots);
  }

  Future<void> clearPattern() async {
    await _secure.delete(key: _patternKey);
  }

  String _hashPattern(List<int> dots) {
    final payload = dots.join('-');
    return sha256.convert(utf8.encode('modamnet::$payload')).toString();
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = '모담넷 잠금을 해제하려면 지문으로 인증하세요',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  bool isLockRequired(SharedPreferences prefs) {
    return readBiometricEnabled(prefs) || readPatternEnabled(prefs);
  }
}
