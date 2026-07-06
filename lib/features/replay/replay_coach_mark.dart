import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';

/// 회상 탭 첫 방문 시 관계 미리보기·길게 누르기 안내.
Future<void> showReplayCoachMarkIfNeeded(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesProvider);
  if (prefs.getBool(prefReplayCoachDone) == true) return;
  if (!context.mounted) return;

  final t = ref.read(translationsProvider);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.touch_app_outlined),
      title: Text(t['replay_coach_title']!),
      content: Text(t['replay_coach_body']!, style: const TextStyle(height: 1.45)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t['got_it']!),
        ),
      ],
    ),
  );
  await prefs.setBool(prefReplayCoachDone, true);
}
