import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/app_lock_service.dart';
import 'pattern_lock_screen.dart';

/// 로그인/게스트 이후 기기 잠금(지문·패턴) 게이트.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = true;
  bool _usePattern = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final prefs = ref.read(preferencesProvider);
      if (AppLockService.instance.isLockRequired(prefs)) {
        setState(() => _unlocked = false);
      }
    } else if (state == AppLifecycleState.resumed && !_unlocked) {
      _tryUnlock();
    }
  }

  Future<void> _bootstrap() async {
    final prefs = ref.read(preferencesProvider);
    final lock = AppLockService.instance;
    if (!lock.isLockRequired(prefs)) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }
    final patternOn = lock.readPatternEnabled(prefs) && await lock.hasPattern();
    setState(() {
      _usePattern = patternOn;
      _checking = false;
    });
    await _tryUnlock();
  }

  Future<void> _tryUnlock() async {
    final prefs = ref.read(preferencesProvider);
    final lock = AppLockService.instance;
    if (lock.readBiometricEnabled(prefs)) {
      final can = await lock.canCheckBiometrics();
      if (can) {
        final ok = await lock.authenticateBiometric();
        if (ok && mounted) {
          setState(() => _unlocked = true);
          return;
        }
      }
    }
    if (lock.readPatternEnabled(prefs) && await lock.hasPattern()) {
      if (mounted) setState(() => _usePattern = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) return widget.child;

    if (_usePattern) {
      return PatternLockScreen(
        mode: PatternLockMode.unlock,
        title: '패턴 잠금',
        subtitle: '등록한 패턴을 그려 잠금을 해제하세요',
        onUnlocked: () => setState(() => _unlocked = true),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.18),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fingerprint_rounded, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 20),
                  Text('모담넷 잠금', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    '지문으로 잠금을 해제하세요',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _tryUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('지문 인증'),
                  ),
                  if (ref.read(preferencesProvider).getBool(prefAppLockPattern) == true) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _usePattern = true),
                      child: const Text('패턴으로 해제'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
