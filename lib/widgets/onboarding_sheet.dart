import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs.dart';
import '../providers/app_providers.dart';

/// 첫 실행 시 핵심 사용법을 안내합니다.
Future<void> showOnboardingIfNeeded(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesProvider);
  if (prefs.getBool(prefOnboardingDone) == true) return;
  if (!context.mounted) return;

  final t = ref.read(translationsProvider);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t['onboarding_title']!, style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _row(ctx, Icons.mic_rounded, t['onboarding_mic']!),
          _row(ctx, Icons.camera_alt_rounded, t['onboarding_camera']!),
          _row(ctx, Icons.search_rounded, t['onboarding_search']!),
          _row(ctx, Icons.location_on_outlined, t['onboarding_recall']!),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(t['got_it']!)),
          ),
        ],
      ),
    ),
  );
  await prefs.setBool(prefOnboardingDone, true);
}

Widget _row(BuildContext context, IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}
