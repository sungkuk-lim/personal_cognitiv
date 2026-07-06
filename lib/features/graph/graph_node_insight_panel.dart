import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../models/memory.dart';
import '../../providers/subscription_providers.dart';
import '../../services/entitlement_service.dart';
import '../../utils/graph_keyword_focus.dart';
import 'graph_layout.dart';
import 'graph_node_insight.dart';

/// #1 인사이트 · #2 타임라인 · #4 추천 · #5 코치 · #6 테마 허브 패널.
class GraphNodeInsightPanel extends ConsumerWidget {
  const GraphNodeInsightPanel({
    super.key,
    required this.node,
    required this.insight,
    required this.imagePaths,
    required this.localeCode,
    required this.translations,
    this.onMemoryTap,
    this.onProTap,
  });

  final GraphNodeData node;
  final GraphNodeInsight insight;
  final Map<String, List<String>> imagePaths;
  final String localeCode;
  final Map<String, String> translations;
  final void Function(Memory memory)? onMemoryTap;
  final VoidCallback? onProTap;

  Map<String, String> get t => translations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPro = ref.watch(hasProEntitlementProvider);
    final showFull = isPro;

    if (insight.totalCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          t['graph_insight_empty']!,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightStatsCard(
            insight: insight,
            node: node,
            localeCode: localeCode,
            t: t,
            locked: !showFull,
            onUnlock: onProTap,
          ),
          if (insight.hasCoachNudge && showFull) ...[
            const SizedBox(height: 8),
            _CoachNudgeBanner(
              days: insight.coachNudgeDays ?? 0,
              name: node.title,
              t: t,
            ),
          ] else if (insight.hasCoachNudge && !showFull) ...[
            const SizedBox(height: 8),
            _ProTeaserChip(
              label: t['graph_insight_coach_pro']!,
              onTap: onProTap,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                t['graph_insight_timeline_title']!,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...insight.timelineMemories.take(showFull ? 8 : 3).map(
                (memory) => _TimelineTile(
                  memory: memory,
                  localeCode: localeCode,
                  thumbPath: _thumbFor(memory),
                  title: memoryTimelineTitle(memory, localeCode: localeCode),
                  onTap: () => onMemoryTap?.call(memory),
                ),
              ),
          if (!showFull && insight.timelineMemories.length > 3) ...[
            const SizedBox(height: 4),
            _ProTeaserChip(
              label: t['graph_insight_timeline_pro']!
                  .replaceAll('{count}', '${insight.timelineMemories.length}'),
              onTap: onProTap,
            ),
          ],
          if (insight.hasThemeHub) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: showFull
                  ? () => openGraphKeywordFocus(ref, node.title.trim())
                  : onProTap,
              icon: Icon(
                showFull ? Icons.hub_rounded : Icons.lock_outline_rounded,
                size: 18,
              ),
              label: Text(insight.themeHubLabel),
            ),
          ],
          if (insight.recommendedMemories.isNotEmpty && showFull) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 17, color: AppGraphColors.interest),
                const SizedBox(width: 6),
                Text(
                  t['graph_insight_recommend_title']!,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...insight.recommendedMemories.map(
              (memory) => _TimelineTile(
                memory: memory,
                localeCode: localeCode,
                thumbPath: _thumbFor(memory),
                title: memoryTimelineTitle(memory, localeCode: localeCode),
                onTap: () => onMemoryTap?.call(memory),
                compact: true,
              ),
            ),
          ] else if (insight.recommendedMemories.isNotEmpty && !showFull) ...[
            const SizedBox(height: 8),
            _ProTeaserChip(label: t['graph_insight_recommend_pro']!, onTap: onProTap),
          ],
        ],
      ),
    );
  }

  String? _thumbFor(Memory memory) {
    final paths = imagePaths[memory.id];
    if (paths == null || paths.isEmpty) return null;
    return paths.first;
  }
}

class _InsightStatsCard extends StatelessWidget {
  const _InsightStatsCard({
    required this.insight,
    required this.node,
    required this.localeCode,
    required this.t,
    required this.locked,
    this.onUnlock,
  });

  final GraphNodeInsight insight;
  final GraphNodeData node;
  final String localeCode;
  final Map<String, String> t;
  final bool locked;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  t['graph_insight_title']!,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (locked) ...[
                  const Spacer(),
                  Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.amber.shade700),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(insight.summaryLine, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
            if (!locked) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatChip(
                    icon: Icons.calendar_month_rounded,
                    label: t['graph_insight_stat_90d']!.replaceAll('{n}', '${insight.recent90Count}'),
                  ),
                  _StatChip(
                    icon: Icons.bubble_chart_rounded,
                    label: t['graph_insight_stat_density']!.replaceAll('{n}', '${insight.memoryDensityScore}'),
                  ),
                ],
              ),
              if (insight.topPlaces.isNotEmpty) ...[
                const SizedBox(height: 8),
                _LabelRow(
                  prefix: t['graph_insight_top_places']!,
                  items: insight.topPlaces,
                ),
              ],
              if (insight.topCoPeople.isNotEmpty && node.kind == GraphNodeKind.place) ...[
                const SizedBox(height: 4),
                _LabelRow(
                  prefix: t['graph_insight_top_people']!,
                  items: insight.topCoPeople,
                ),
              ],
              if (insight.topActivities.isNotEmpty) ...[
                const SizedBox(height: 4),
                _LabelRow(
                  prefix: t['graph_insight_top_activities']!,
                  items: insight.topActivities,
                ),
              ],
              if (insight.topEmotions.isNotEmpty) ...[
                const SizedBox(height: 4),
                _LabelRow(
                  prefix: t['graph_insight_top_emotions']!,
                  items: insight.topEmotions,
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(t['graph_insight_unlock']!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.prefix, required this.items});
  final String prefix;
  final List<LabelCount> items;

  @override
  Widget build(BuildContext context) {
    final text = items.map((e) => '${e.label} ${e.count}').join(' · ');
    return Text(
      '$prefix $text',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
    );
  }
}

class _CoachNudgeBanner extends StatelessWidget {
  const _CoachNudgeBanner({required this.days, required this.name, required this.t});
  final int days;
  final String name;
  final Map<String, String> t;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.notifications_active_outlined, size: 20, color: colorScheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t['graph_insight_coach_gap']!
                    .replaceAll('{name}', name)
                    .replaceAll('{days}', '$days'),
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProTeaserChip extends StatelessWidget {
  const _ProTeaserChip({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.amber.shade700),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.memory,
    required this.localeCode,
    required this.title,
    this.thumbPath,
    this.onTap,
    this.compact = false,
  });

  final Memory memory;
  final String localeCode;
  final String title;
  final String? thumbPath;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = localeCode == 'ko'
        ? DateFormat('M월 d일', 'ko').format(memory.createdAt)
        : DateFormat('MMM d', 'en').format(memory.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                dateText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (thumbPath != null && File(thumbPath!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(thumbPath!),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbPlaceholder(context),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.photo_outlined, size: 16),
    );
  }
}
