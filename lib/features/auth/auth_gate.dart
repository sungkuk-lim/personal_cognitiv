import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../providers/app_providers.dart';
import '../../providers/care_dictionary_provider.dart';
import 'app_lock_gate.dart';
import 'login_screen.dart';
import 'password_recovery_screen.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  if (!AppEnv.isConfigured) {
    return Stream<Session?>.value(null);
  }
  return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session);
});

final firebaseUserProvider = StreamProvider<fb.User?>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream<fb.User?>.value(null);
  }
  return fb.FirebaseAuth.instance.authStateChanges();
});

/// 비밀번호 재설정 링크로 앱이 열렸을 때 true.
final passwordRecoveryModeProvider = StateProvider<bool>((ref) => false);

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    if (!AppEnv.isConfigured) return;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryModeProvider.notifier).state = true;
      }
    });
  }

  Widget _lockedApp() => AppLockGate(child: widget.child);

  @override
  Widget build(BuildContext context) {
    if (AppEnv.isConfigured) {
      ref.listen<AsyncValue<Session?>>(authSessionProvider, (previous, next) {
        next.whenData((session) {
          if (session == null || ref.read(guestModeProvider)) return;
          final wasLoggedOut = previous?.valueOrNull == null;
          if (wasLoggedOut) {
            ref.read(careDictionaryProvider.notifier).syncOnLoginSilently();
          }
        });
      });
    }

    final guest = ref.watch(guestModeProvider);
    final recovery = ref.watch(passwordRecoveryModeProvider);
    final firebaseUser = ref.watch(firebaseUserProvider).valueOrNull;

    if (recovery) {
      return PasswordRecoveryScreen(
        onComplete: () {
          ref.read(passwordRecoveryModeProvider.notifier).state = false;
          ref.read(guestModeProvider.notifier).state = false;
        },
      );
    }

    if (!AppEnv.isConfigured) {
      if (guest || firebaseUser != null) return _lockedApp();
      return const LoginScreen();
    }

    final sessionAsync = ref.watch(authSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) {
        if (guest || firebaseUser != null) return _lockedApp();
        return const LoginScreen();
      },
      data: (session) {
        if (session != null || guest || firebaseUser != null) return _lockedApp();
        return const LoginScreen();
      },
    );
  }
}

/// 하위 호환.
typedef AuthScreen = LoginScreen;
