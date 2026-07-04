import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/trust_dashboard_service.dart';

class TrustDashboardScreen extends ConsumerWidget {
  const TrustDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final prefs = ref.watch(preferencesProvider);
    final stats = buildTrustDashboardStats(
      allMemories: ref.watch(memoryListProvider),
      prefs: prefs,
      guestMode: ref.watch(guestModeProvider),
      privacyMode: ref.watch(privacyLocalModeProvider),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t['trust_dashboard_title']!)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t['trust_dashboard_intro']!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: 20),
          _StatCard(
            icon: Icons.phone_android_rounded,
            color: Colors.teal,
            title: t['trust_storage_title']!,
            value: stats.storageIsLocal ? t['trust_storage_local']! : t['trust_storage_cloud']!,
          ),
          _StatCard(
            icon: Icons.edit_note_rounded,
            color: Colors.teal.shade600,
            title: t['trust_user_records']!,
            value: '${stats.userRecordCount}',
          ),
          _StatCard(
            icon: Icons.auto_awesome_rounded,
            color: Colors.deepPurple,
            title: t['trust_ai_assist']!,
            value: '${stats.aiAssistCount}',
            subtitle: t['trust_ai_assist_hint']!,
          ),
          _StatCard(
            icon: Icons.visibility_off_outlined,
            color: Colors.blueGrey,
            title: t['trust_hidden_internal']!,
            value: '${stats.hiddenInternalCount}',
            subtitle: t['trust_hidden_internal_hint']!,
          ),
          const SizedBox(height: 8),
          Text(t['trust_features_title']!, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _ToggleRow(label: t['trust_pulse_enabled']!, enabled: stats.memoryPulseEnabled),
          _ToggleRow(label: t['trust_recall_enabled']!, enabled: stats.proactiveRecallEnabled),
          _ToggleRow(label: t['trust_graph_ai']!, enabled: stats.graphAiEnabled),
          _ToggleRow(label: t['trust_cloud']!, enabled: stats.cloudConfigured),
          const SizedBox(height: 16),
          Text(t['trust_promise']!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16)),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(enabled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18, color: enabled ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
