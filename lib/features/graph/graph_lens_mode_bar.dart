import 'package:flutter/material.dart';

import '../../core/graph_display_mode.dart';
import '../../core/graph_hub_config.dart';
import '../../core/graph_view_lens.dart';
import '../../utils/graph_time_filter.dart';

/// 사람 · 기억 렌즈 + 「보기」기간 + 그래프/목록 아이콘.
class GraphLensModeBar extends StatelessWidget {
  const GraphLensModeBar({
    super.key,
    required this.lens,
    required this.timeRange,
    required this.personLabel,
    required this.memoryLabel,
    required this.viewTitle,
    required this.range7dLabel,
    required this.range30dLabel,
    required this.range90dLabel,
    required this.rangeAllLabel,
    required this.onLensChanged,
    required this.onTimeRangeChanged,
    this.helpTooltip,
    this.onHelpPressed,
    this.displayMode,
    this.onDisplayModeChanged,
    this.graphModeTooltip,
    this.listModeTooltip,
  });

  final GraphViewLens lens;
  final GraphTimeRange timeRange;
  final String personLabel;
  final String memoryLabel;
  final String viewTitle;
  final String range7dLabel;
  final String range30dLabel;
  final String range90dLabel;
  final String rangeAllLabel;
  final ValueChanged<GraphViewLens> onLensChanged;
  final ValueChanged<GraphTimeRange> onTimeRangeChanged;
  final String? helpTooltip;
  final VoidCallback? onHelpPressed;
  final GraphDisplayMode? displayMode;
  final ValueChanged<GraphDisplayMode>? onDisplayModeChanged;
  final String? graphModeTooltip;
  final String? listModeTooltip;

  GraphViewLens get _selectedLens {
    if (lens == GraphViewLens.timeline || lens == GraphViewLens.aiInsight) {
      return GraphViewLens.memory;
    }
    return lens;
  }

  String _rangeLabel(GraphTimeRange range) => switch (range) {
        GraphTimeRange.days7 => range7dLabel,
        GraphTimeRange.days30 => range30dLabel,
        GraphTimeRange.days90 => range90dLabel,
        GraphTimeRange.all => rangeAllLabel,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = displayMode;
    final onMode = onDisplayModeChanged;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          children: [
            if (onHelpPressed != null)
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, size: 22),
                tooltip: helpTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: onHelpPressed,
              ),
            Expanded(
              flex: 3,
              child: SegmentedButton<GraphViewLens>(
                segments: [
                  ButtonSegment(
                    value: GraphViewLens.person,
                    label: Text(personLabel, style: const TextStyle(fontSize: 12)),
                    icon: const Icon(Icons.person_outline_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: GraphViewLens.memory,
                    label: Text(memoryLabel, style: const TextStyle(fontSize: 12)),
                    icon: const Icon(Icons.memory_rounded, size: 16),
                  ),
                ],
                selected: {_selectedLens},
                onSelectionChanged: (s) => onLensChanged(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 1,
              child: _GraphViewRangeDropdown(
                viewTitle: viewTitle,
                rangeLabel: _rangeLabel(timeRange),
                range7dLabel: range7dLabel,
                range30dLabel: range30dLabel,
                range90dLabel: range90dLabel,
                rangeAllLabel: rangeAllLabel,
                timeRange: timeRange,
                onTimeRangeChanged: onTimeRangeChanged,
              ),
            ),
            if (mode != null && onMode != null) ...[
              const SizedBox(width: 2),
              _GraphDisplayModeIconToggle(
                mode: mode,
                onChanged: onMode,
                graphTooltip: graphModeTooltip ?? 'Graph',
                listTooltip: listModeTooltip ?? 'List',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GraphDisplayModeIconToggle extends StatelessWidget {
  const _GraphDisplayModeIconToggle({
    required this.mode,
    required this.onChanged,
    required this.graphTooltip,
    required this.listTooltip,
  });

  final GraphDisplayMode mode;
  final ValueChanged<GraphDisplayMode> onChanged;
  final String graphTooltip;
  final String listTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeIcon(
            icon: Icons.hub_outlined,
            tooltip: graphTooltip,
            selected: mode == GraphDisplayMode.canvas,
            onTap: () => onChanged(GraphDisplayMode.canvas),
          ),
          _ModeIcon(
            icon: Icons.view_list_rounded,
            tooltip: listTooltip,
            selected: mode == GraphDisplayMode.list,
            onTap: () => onChanged(GraphDisplayMode.list),
          ),
        ],
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _GraphViewRangeDropdown extends StatelessWidget {
  const _GraphViewRangeDropdown({
    required this.viewTitle,
    required this.rangeLabel,
    required this.range7dLabel,
    required this.range30dLabel,
    required this.range90dLabel,
    required this.rangeAllLabel,
    required this.timeRange,
    required this.onTimeRangeChanged,
  });

  final String viewTitle;
  final String rangeLabel;
  final String range7dLabel;
  final String range30dLabel;
  final String range90dLabel;
  final String rangeAllLabel;
  final GraphTimeRange timeRange;
  final ValueChanged<GraphTimeRange> onTimeRangeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.45);

    return MenuAnchor(
      style: MenuStyle(
        visualDensity: VisualDensity.compact,
        alignment: Alignment.bottomCenter,
      ),
      builder: (context, controller, child) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    viewTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          rangeLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (final range in GraphTimeRange.values)
          MenuItemButton(
            onPressed: () => onTimeRangeChanged(range),
            trailingIcon: range == timeRange ? const Icon(Icons.check, size: 18) : null,
            child: Text(
              switch (range) {
                GraphTimeRange.days7 => range7dLabel,
                GraphTimeRange.days30 => range30dLabel,
                GraphTimeRange.days90 => range90dLabel,
                GraphTimeRange.all => rangeAllLabel,
              },
            ),
          ),
      ],
    );
  }
}

/// AI 렌즈 — 인사이트 한 줄 + 허브 전환을 한 행에 표시.
class GraphAiHubToolbar extends StatelessWidget {
  const GraphAiHubToolbar({
    super.key,
    required this.insights,
    required this.emptyHint,
    required this.mode,
    required this.memoryHubLabel,
    required this.eventHubLabel,
    required this.onModeChanged,
  });

  final List<String> insights;
  final String emptyHint;
  final GraphHubViewMode mode;
  final String memoryHubLabel;
  final String eventHubLabel;
  final ValueChanged<GraphHubViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insightLine = insights.isEmpty
        ? emptyHint
        : insights.take(3).map((line) => '✔ $line').join('  ·  ');

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.38),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 18,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    insightLine,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 96,
              height: 32,
              child: SegmentedButton<GraphHubViewMode>(
                segments: [
                  ButtonSegment(
                    value: GraphHubViewMode.memoryHub,
                    icon: const Icon(Icons.auto_stories_rounded, size: 15),
                    tooltip: memoryHubLabel,
                  ),
                  ButtonSegment(
                    value: GraphHubViewMode.eventHub,
                    icon: const Icon(Icons.event_rounded, size: 15),
                    tooltip: eventHubLabel,
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => onModeChanged(selection.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                showSelectedIcon: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 인사이트 렌즈 — 상단 요약 카드 (기억 렌즈 등 단독 표시용).
class GraphAiInsightPanel extends StatelessWidget {
  const GraphAiInsightPanel({
    super.key,
    required this.insights,
    required this.title,
    required this.emptyHint,
  });

  final List<String> insights;
  final String title;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insightLine = insights.isEmpty
        ? emptyHint
        : insights.take(3).map((line) => '✔ $line').join('  ·  ');

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 18,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    insightLine,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
