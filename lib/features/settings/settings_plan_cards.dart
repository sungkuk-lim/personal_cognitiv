import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_maturity.dart';
import '../../core/env.dart';
import '../../core/prefs.dart';
import '../../core/subscription_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/local_memory_store.dart';
import '../subscription/paywall_sheet.dart';
import '../subscription/pro_saas_dashboard.dart';

/// 무료·Pro 경계 요약 + 관계망 AI 활성 조건 안내.
class SettingsPlanOverviewCard extends ConsumerWidget {
  const SettingsPlanOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isPro = ref.watch(hasProEntitlementProvider);
    final theme = Theme.of(context);
    final localOnly = isLocalOnlyMode(
      ref.watch(preferencesProvider),
      privacyMode: ref.watch(privacyLocalModeProvider),
      guestMode: ref.watch(guestModeProvider),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isPro ? Icons.workspace_premium_rounded : Icons.favorite_outline,
                    color: isPro ? Colors.amber.shade700 : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPro ? t['settings_plan_pro_active']! : t['settings_plan_free_active']!,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t['settings_plan_compare_intro']!,
                style: TextStyle(fontSize: 13, height: 1.45, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _TierRow(
                label: t['settings_tier_free']!,
                bullets: [
                  t['settings_tier_free_1']!,
                  t['settings_tier_free_2']!,
                  t['settings_tier_free_3']!,
                ],
                highlighted: !isPro,
              ),
              const SizedBox(height: 10),
              _TierRow(
                label: t['settings_tier_pro']!,
                bullets: SubscriptionConfig.proBenefitKeys
                    .map((k) => t[k]!)
                    .take(5)
                    .toList(),
                highlighted: isPro,
                accent: Colors.amber.shade800,
              ),
              if (!isPro) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => showProPaywall(context, ref),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 20),
                  label: Text(t['pro_plan']!),
                ),
              ] else ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ProSaasDashboardScreen()),
                  ),
                  icon: const Icon(Icons.cloud_sync_outlined, size: 20),
                  label: Text(t['pro_saas_title']!),
                ),
              ],
              if (localOnly) ...[
                const SizedBox(height: 10),
                Text(
                  t['settings_plan_privacy_note']!,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.error.withValues(alpha: 0.85)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = met ? Colors.green.shade600 : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: met ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.label,
    required this.bullets,
    required this.highlighted,
    this.accent,
  });

  final String label;
  final List<String> bullets;
  final bool highlighted;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = highlighted
        ? (accent ?? theme.colorScheme.primary).withValues(alpha: 0.45)
        : theme.colorScheme.outline.withValues(alpha: 0.25);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: highlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: accent ?? theme.colorScheme.onSurface)),
          const SizedBox(height: 6),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 12, height: 1.35))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 관계망 AI(하이브리드) 스위치 위 상태 카드.
class SettingsGraphAiStatusCard extends ConsumerWidget {
  const SettingsGraphAiStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final privacyMode = ref.watch(privacyLocalModeProvider);
    final guestMode = ref.watch(guestModeProvider);
    final isPro = ref.watch(hasProEntitlementProvider);
    final localOnly = isLocalOnlyMode(
      ref.watch(preferencesProvider),
      privacyMode: privacyMode,
      guestMode: guestMode,
    );
    final graphAiLocked = localOnly ||
        (requiresProCloudForGraphAi && (!AppEnv.isConfigured || !isPro));
    final enabled = !graphAiLocked && ref.watch(graphAiEnabledProvider);

    final privacyOk = !privacyMode && !readPrivacyLocalMode(ref.watch(preferencesProvider));
    final loginOk = !guestMode && AppEnv.isConfigured;
    final proOk = isPro || !requiresProCloudForGraphAi;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (localOnly) {
      statusText = t['settings_graph_ai_locked_privacy']!;
      statusIcon = Icons.lock_outline;
      statusColor = theme.colorScheme.error;
    } else if (graphAiLocked) {
      statusText = t['settings_graph_ai_locked_pro']!;
      statusIcon = Icons.workspace_premium_outlined;
      statusColor = Colors.amber.shade800;
    } else if (enabled) {
      statusText = t['settings_graph_ai_status_on']!;
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green.shade700;
    } else {
      statusText = t['settings_graph_ai_status_off']!;
      statusIcon = Icons.pause_circle_outline;
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(statusText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['settings_graph_ai_req_title']!, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _RequirementRow(label: t['settings_graph_ai_req_privacy']!, met: privacyOk),
                  _RequirementRow(label: t['settings_graph_ai_req_login']!, met: loginOk),
                  _RequirementRow(label: t['settings_graph_ai_req_pro']!, met: proOk),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(t['settings_graph_ai_when_active_title']!, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            ...['settings_graph_ai_feat_1', 'settings_graph_ai_feat_2', 'settings_graph_ai_feat_3'].map(
              (k) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('· ${t[k]!}', style: const TextStyle(fontSize: 12, height: 1.35)),
              ),
            ),
            if (graphAiLocked && !localOnly) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => showProPaywall(context, ref, reasonKey: 'pro_reason_graph'),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text(t['settings_graph_ai_unlock']!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
