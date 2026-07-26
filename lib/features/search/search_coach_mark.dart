import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';

/// 검색 탭 첫 방문 시 로컬 vs Pro 검색 차이 안내.
Future<void> showSearchCoachMarkIfNeeded(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesProvider);
  if (prefs.getBool(prefSearchCoachDone) == true) return;
  if (!context.mounted) return;

  final t = ref.read(translationsProvider);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.search_rounded),
      title: Text(t['search_coach_title']!),
      content: Text(t['search_coach_body']!, style: const TextStyle(height: 1.45)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t['got_it']!),
        ),
      ],
    ),
  );
  await prefs.setBool(prefSearchCoachDone, true);
}
