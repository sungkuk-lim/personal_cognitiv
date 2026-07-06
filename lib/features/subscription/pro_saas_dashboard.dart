import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/subscription_config.dart';
import '../../features/subscription/paywall_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../providers/subscription_providers.dart';
import '../../services/entitlement_service.dart';
import '../../services/local_memory_store.dart';
import '../../services/pro_saas_service.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/memory_entity_extract.dart';

/// Pro SaaS 대시보드 — 쿼터·동기화·Wrapped·기념일.
class ProSaasDashboardScreen extends ConsumerStatefulWidget {
  const ProSaasDashboardScreen({super.key});

  @override
  ConsumerState<ProSaasDashboardScreen> createState() => _ProSaasDashboardScreenState();
}

class _ProSaasDashboardScreenState extends ConsumerState<ProSaasDashboardScreen> {
  ProSaasSnapshot? _snapshot;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final memories = ref.read(memoryListProvider);
    final snap = await loadProSaasSnapshot(
      prefs: ref.read(preferencesProvider),
      subscription: ref.read(subscriptionStatusProvider),
      allMemories: memories,
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    );
    if (mounted) setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final snap = await runProCloudSync(
      prefs: ref.read(preferencesProvider),
      subscription: ref.read(subscriptionStatusProvider),
      allMemories: ref.read(memoryListProvider),
      privacyMode: ref.read(privacyLocalModeProvider),
      guestMode: ref.read(guestModeProvider),
    );
    await ref.read(memoryListProvider.notifier).reload();
    if (mounted) {
      setState(() {
        _snapshot = snap;
        _syncing = false;
      });
      final t = ref.read(translationsProvider);
      final report = snap.syncReport;
      if (report != null && report.hasWork) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t['pro_saas_sync_done']!
                  .replaceAll('{up}', '${report.uploaded}')
                  .replaceAll('{fail}', '${report.failed}'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final locale = ref.watch(languageProvider).languageCode;
    final isPro = ref.watch(hasProEntitlementProvider);
    final memories = ref.watch(memoryListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t['pro_saas_title']!)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isPro) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.workspace_premium_rounded, color: Colors.amber.shade700),
                      title: Text(t['pro_saas_upsell']!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showProPaywall(context, ref),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isPro && _snapshot != null) ...[
                  _QuotaCard(
                    title: t['pro_saas_quota_title']!,
                    chat: _snapshot!.subscription?.chatUsed ?? 0,
                    chatMax: SubscriptionConfig.quotaChatMonthly,
                    embed: _snapshot!.subscription?.embeddingUsed ?? 0,
                    embedMax: SubscriptionConfig.quotaEmbeddingMonthly,
                    vision: _snapshot!.subscription?.visionUsed ?? 0,
                    visionMax: SubscriptionConfig.quotaVisionMonthly,
                    labels: t,
                  ),
                  const SizedBox(height: 12),
                  _CloudCard(
                    snapshot: _snapshot!,
                    syncing: _syncing,
                    locale: locale,
                    t: t,
                    onSync: _sync,
                  ),
                  const SizedBox(height: 12),
                  _WrappedCard(memories: memories, locale: locale, t: t),
                  const SizedBox(height: 12),
                  _AnniversaryCard(memories: memories, locale: locale, t: t),
                ],
              ],
            ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({
    required this.title,
    required this.chat,
    required this.chatMax,
    required this.embed,
    required this.embedMax,
    required this.vision,
    required this.visionMax,
    required this.labels,
  });

  final String title;
  final int chat;
  final int chatMax;
  final int embed;
  final int embedMax;
  final int vision;
  final int visionMax;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _QuotaBar(label: labels['pro_saas_quota_chat']!, used: chat, max: chatMax),
            _QuotaBar(label: labels['pro_saas_quota_embed']!, used: embed, max: embedMax),
            _QuotaBar(label: labels['pro_saas_quota_vision']!, used: vision, max: visionMax),
          ],
        ),
      ),
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.label, required this.used, required this.max});
  final String label;
  final int used;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · $used / $max', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ratio),
        ],
      ),
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard({
    required this.snapshot,
    required this.syncing,
    required this.locale,
    required this.t,
    required this.onSync,
  });

  final ProSaasSnapshot snapshot;
  final bool syncing;
  final String locale;
  final Map<String, String> t;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final last = snapshot.lastSyncAt;
    final lastText = last == null
        ? t['pro_saas_sync_never']!
        : (locale == 'ko'
            ? DateFormat('M월 d일 HH:mm', 'ko').format(last)
            : DateFormat('MMM d HH:mm', 'en').format(last));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t['pro_saas_cloud_title']!, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${t['pro_saas_cloud_count']!}: ${snapshot.cloudMemoryCount}'),
            Text('${t['pro_saas_local_pending']!}: ${snapshot.localOnlyCount}'),
            Text('${t['pro_saas_last_sync']!}: $lastText'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(t['pro_saas_sync_now']!),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrappedCard extends ConsumerWidget {
  const _WrappedCard({
    required this.memories,
    required this.locale,
    required this.t,
  });

  final List<Memory> memories;
  final String locale;
  final Map<String, String> t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final yearMemories = memories.where((m) => m.createdAt.year == year).toList();
    final people = <String, int>{};
    for (final m in yearMemories) {
      for (final p in extractMemoryEntities(m, localeCode: locale).people) {
        people[p] = (people[p] ?? 0) + 1;
      }
    }
    final top = people.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = top.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['pro_saas_wrapped_title']!.replaceAll('{year}', '$year'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(t['pro_saas_wrapped_count']!.replaceAll('{n}', '${yearMemories.length}')),
            if (top3.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${t['pro_saas_wrapped_people']!}: ${top3.map((e) => '${e.key}(${e.value})').join(' · ')}',
                style: const TextStyle(height: 1.35),
              ),
            ],
            if (top3.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: top3
                    .map((e) => ActionChip(
                          label: Text(e.key),
                          onPressed: () => openGraphKeywordFocus(ref, e.key),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnniversaryCard extends StatelessWidget {
  const _AnniversaryCard({
    required this.memories,
    required this.locale,
    required this.t,
  });

  final List<Memory> memories;
  final String locale;
  final Map<String, String> t;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final anniversaries = memories.where((m) {
      final d = m.createdAt;
      return d.month == now.month && d.day == now.day && d.year < now.year;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['pro_saas_anniversary_title']!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (anniversaries.isEmpty)
              Text(t['pro_saas_anniversary_empty']!)
            else ...[
              Text(t['pro_saas_anniversary_count']!.replaceAll('{n}', '${anniversaries.length}')),
              const SizedBox(height: 6),
              ...anniversaries.take(3).map((m) {
                final years = now.year - m.createdAt.year;
                final line = m.content.trim();
                final preview = line.length > 36 ? '${line.substring(0, 35)}…' : line;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $years${locale == 'ko' ? '년 전' : 'y ago'} — $preview',
                      style: const TextStyle(fontSize: 13, height: 1.35)),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
