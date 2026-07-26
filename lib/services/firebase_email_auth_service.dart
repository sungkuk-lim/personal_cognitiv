import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_config.dart';
import '../core/crash_reporting.dart';
import '../core/env.dart';
import '../firebase_options.dart';

/// 이메일 인증: Firebase Auth(가능 시) + Supabase 세션 브리지.
///
/// Firebase Console에서 Authentication이 아직 꺼져 있으면
/// (`CONFIGURATION_NOT_FOUND`) Supabase만으로 가입·로그인합니다.
class FirebaseEmailAuthService {
  FirebaseEmailAuthService._();
  static final FirebaseEmailAuthService instance = FirebaseEmailAuthService._();

  bool get isFirebaseReady =>
      CrashReporting.isFirebaseReady || Firebase.apps.isNotEmpty;

  Future<void> ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    final options = DefaultFirebaseOptions.android;
    if (options.apiKey.contains('Placeholder')) {
      throw StateError('Firebase 설정이 없습니다. google-services.json을 확인하세요.');
    }
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  bool _isFirebaseAuthNotConfigured(Object error) {
    if (error is! fb.FirebaseAuthException) return false;
    final blob = '${error.code} ${error.message}'.toLowerCase();
    return blob.contains('configuration_not_found') ||
        blob.contains('identity toolkit') ||
        blob.contains('api has not been used') ||
        (error.code == 'internal-error' && blob.contains('configuration'));
  }

  Future<void> _signInSupabase({
    required String email,
    required String password,
  }) async {
    if (!AppEnv.isConfigured) {
      throw StateError(
        '클라우드 설정이 없는 빌드입니다. scripts/build_release.ps1 로 다시 빌드하세요.',
      );
    }
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> _signUpSupabase({
    required String email,
    required String password,
  }) async {
    if (!AppEnv.isConfigured) {
      throw StateError(
        '클라우드 설정이 없는 빌드입니다. scripts/build_release.ps1 로 다시 빌드하세요.',
      );
    }
    try {
      await Supabase.instance.client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already')) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await ensureFirebase();
      await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (AppEnv.isConfigured) {
        await _signInSupabase(email: email, password: password);
      }
    } on fb.FirebaseAuthException catch (e) {
      if (_isFirebaseAuthNotConfigured(e)) {
        debugPrint('Firebase Auth not configured — Supabase sign-in: $e');
        await _signInSupabase(email: email, password: password);
        return;
      }
      rethrow;
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    try {
      await ensureFirebase();
      await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (AppEnv.isConfigured) {
        await _signUpSupabase(email: email, password: password);
      }
    } on fb.FirebaseAuthException catch (e) {
      if (_isFirebaseAuthNotConfigured(e)) {
        debugPrint('Firebase Auth not configured — Supabase sign-up: $e');
        await _signUpSupabase(email: email, password: password);
        return;
      }
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await ensureFirebase();
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      if (!_isFirebaseAuthNotConfigured(e)) rethrow;
      debugPrint('Firebase reset skipped (not configured): $e');
    }
    if (AppEnv.isConfigured) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email,
          redirectTo: supabaseAuthRedirectUrl(),
        );
      } catch (e) {
        debugPrint('Supabase reset mail skipped: $e');
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await fb.FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
    if (AppEnv.isConfigured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
  }

  String friendlyError(Object error) {
    if (error is fb.FirebaseAuthException) {
      if (_isFirebaseAuthNotConfigured(error)) {
        return 'Firebase Authentication이 아직 켜지지 않았습니다.\n'
            '콘솔에서 이메일/비밀번호를 활성화하거나,\n'
            '앱을 업데이트한 뒤 다시 시도해 주세요.';
      }
      switch (error.code) {
        case 'invalid-email':
          return '이메일 형식이 올바르지 않습니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 맞지 않습니다.\n「비밀번호 찾기」로 재설정해 보세요.';
        case 'email-already-in-use':
          return '이미 가입된 이메일입니다. 로그인을 시도하세요.';
        case 'weak-password':
          return '비밀번호는 6자 이상으로 설정해 주세요.';
        case 'too-many-requests':
          return '시도가 너무 많습니다. 잠시 후 다시 시도하세요.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해 주세요.';
        case 'internal-error':
          final msg = error.message ?? '';
          if (msg.toUpperCase().contains('CONFIGURATION_NOT_FOUND')) {
            return 'Firebase Authentication이 아직 켜지지 않았습니다.\n'
                '콘솔 → Authentication → 이메일/비밀번호 사용 설정';
          }
          return msg.isNotEmpty ? msg : '일시적인 오류입니다. 잠시 후 다시 시도하세요.';
        default:
          return error.message ?? error.code;
      }
    }
    if (error is AuthException) {
      final lower = error.message.toLowerCase();
      if (lower.contains('invalid login')) {
        return '이메일 또는 비밀번호가 맞지 않습니다.';
      }
      if (lower.contains('email not confirmed')) {
        return '이메일 인증이 필요합니다. 가입 메일의 링크를 눌러 주세요.';
      }
      if (lower.contains('already') || lower.contains('registered')) {
        return '이미 가입된 이메일입니다. 로그인을 시도하세요.';
      }
      return error.message;
    }
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }
}
