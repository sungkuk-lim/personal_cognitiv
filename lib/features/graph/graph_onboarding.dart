import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';

const String prefGraphOnboardingDone = 'graph_onboarding_done';

/// 관계망 탭 첫 방문 시 배지·기간·포커스 사용법을 안내합니다.
Future<void> showGraphOnboardingIfNeeded(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesProvider);
  if (prefs.getBool(prefGraphOnboardingDone) == true) return;
  if (!context.mounted) return;

  final t = ref.read(translationsProvider);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(ctx).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t['graph_onboarding_title']!,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _row(ctx, Icons.hub_outlined, t['graph_onboarding_hub']!),
              _row(ctx, Icons.view_sidebar_outlined, t['graph_onboarding_rail']!),
              _row(ctx, Icons.date_range_outlined, t['graph_onboarding_range']!),
              _row(ctx, Icons.filter_alt_outlined, t['graph_onboarding_focus']!),
              _row(ctx, Icons.auto_awesome_motion, t['graph_onboarding_auto_expand']!),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t['got_it']!),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await prefs.setBool(prefGraphOnboardingDone, true);
}

Widget _row(BuildContext context, IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    ),
  );
}
