import 'package:flutter/material.dart';

import '../../services/graph_insights_service.dart';
import '../../utils/graph_time_filter.dart';

/// 관계망 사용 안내 — 헤더 아이콘 탭 시 카드로 표시.
void showGraphHelpSheet(
  BuildContext context, {
  required Map<String, String> t,
  required GraphTimeRange timeRange,
  required int totalCount,
  required int visibleCount,
  List<GraphInsight> insights = const [],
}) {
  final theme = Theme.of(context);
  final showRangeNote = timeRange != GraphTimeRange.all && totalCount > visibleCount;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.paddingOf(ctx).bottom;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: insights.isEmpty ? 0.48 : 0.55,
        maxChildSize: 0.82,
        minChildSize: 0.35,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.hub_outlined, color: theme.colorScheme.primary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t['graph_help_title']!,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    t['graph_insights_help_title']!,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: insights
                        .map(
                          (i) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(i.message, style: const TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                _HelpSection(
                  icon: Icons.explore_outlined,
                  text: t['graph_role_hint']!,
                ),
                const SizedBox(height: 12),
                _HelpSection(
                  icon: Icons.date_range_outlined,
                  text: showRangeNote
                      ? t['graph_range_banner']!
                          .replaceAll('{total}', '$totalCount')
                          .replaceAll('{shown}', '$visibleCount')
                      : t['graph_range_help']!,
                ),
                const SizedBox(height: 12),
                _HelpSection(
                  icon: Icons.person_pin_circle_outlined,
                  text: t['graph_satellite_tap_hint']!,
                ),
                const SizedBox(height: 12),
                _HelpSection(
                  icon: Icons.touch_app_outlined,
                  text: t['graph_hint']!,
                ),
                const SizedBox(height: 12),
                _HelpSection(
                  icon: Icons.link_rounded,
                  text: t['graph_bridge_hint']!,
                ),
                const SizedBox(height: 12),
                _HelpSection(
                  icon: Icons.verified_user_outlined,
                  text: t['graph_trust_sheet_source_body']!,
                ),
                const SizedBox(height: 12),
                _HelpSection(
                  icon: Icons.timeline_rounded,
                  text: '${t['graph_edge_legend_title']!}\n${t['graph_edge_legend_body']!}',
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
