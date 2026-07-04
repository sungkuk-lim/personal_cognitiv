import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_maturity.dart';
import '../core/prefs.dart';
import '../providers/app_providers.dart';

/// 완성도 [kProCloudGatePercent]% 이상 최초 진입 시 Pro·클라우드 게이트 전환을 안내합니다.
Future<void> maybeShowAppMaturityDialog(BuildContext context, WidgetRef ref) async {
  if (!isAppMaturityProductionReady) return;

  final prefs = ref.read(preferencesProvider);
  if (prefs.getBool(prefCompletionMilestoneNotified) == true) return;

  await prefs.setBool(prefCompletionMilestoneNotified, true);
  if (!context.mounted) return;

  final t = ref.read(translationsProvider);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t['app_maturity_title']!),
      content: Text(t['app_maturity_body']!.replaceAll('{percent}', '$kAppCompletionPercent')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t['ok']!)),
      ],
    ),
  );
}
