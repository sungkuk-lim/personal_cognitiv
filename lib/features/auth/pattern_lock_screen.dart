import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import 'pattern_lock_pad.dart';

enum PatternLockMode { unlock, register }

/// 패턴 잠금 해제 / 등록 화면.
class PatternLockScreen extends StatefulWidget {
  const PatternLockScreen({
    super.key,
    required this.mode,
    required this.title,
    required this.subtitle,
    this.onUnlocked,
    this.onRegistered,
    this.onCancel,
  });

  final PatternLockMode mode;
  final String title;
  final String subtitle;
  final VoidCallback? onUnlocked;
  final VoidCallback? onRegistered;
  final VoidCallback? onCancel;

  @override
  State<PatternLockScreen> createState() => _PatternLockScreenState();
}

class _PatternLockScreenState extends State<PatternLockScreen> {
  List<int>? _first;
  String? _hint;
  bool _error = false;

  bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _onComplete(List<int> dots) async {
    final lock = AppLockService.instance;
    if (widget.mode == PatternLockMode.unlock) {
      final ok = await lock.verifyPattern(dots);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked?.call();
      } else {
        setState(() {
          _error = true;
          _hint = '패턴이 일치하지 않습니다.';
        });
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) setState(() => _error = false);
      }
      return;
    }

    if (_first == null) {
      setState(() {
        _first = dots;
        _hint = '같은 패턴을 다시 그려 확인하세요.';
        _error = false;
      });
      return;
    }

    if (!_eq(_first!, dots)) {
      setState(() {
        _first = null;
        _hint = '패턴이 다릅니다. 처음부터 다시 그려 주세요.';
        _error = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) setState(() => _error = false);
      return;
    }

    await lock.savePattern(dots);
    if (!mounted) return;
    widget.onRegistered?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.12),
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: widget.onCancel == null
                      ? const SizedBox(height: 40)
                      : IconButton(
                          onPressed: widget.onCancel,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                Text(widget.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_hint != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _error ? theme.colorScheme.error : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                PatternLockPad(onCompleted: _onComplete, errorFlash: _error),
                const Spacer(),
                Text(
                  '최소 4개 점을 연결하세요',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
