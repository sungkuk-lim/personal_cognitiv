import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../providers/app_providers.dart';
import '../../utils/graph_context_lens.dart';

/// 관계망 상단 맥락 렌즈 — 입력 카테고리와 같은 축으로 필터합니다.
///
/// 와이어 구조:
/// ┌──────────────────────────────────────────────┐
/// │ 🔍 맥락 렌즈    기억 12개 · 전체 48개 중      │
/// │ [전체][일반][가족][연인][친구][반려견/반려묘]→│
/// └──────────────────────────────────────────────┘
class GraphContextLensBar extends ConsumerWidget {
  const GraphContextLensBar({
    super.key,
    required this.lens,
    required this.visibleCount,
    required this.rangeCount,
    required this.onLensChanged,
  });

  final GraphContextLens lens;
  final int visibleCount;
  final int rangeCount;
  final ValueChanged<GraphContextLens> onLensChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(languageProvider).languageCode;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lensActive = lens != GraphContextLens.all;

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  t['graph_lens_title']!,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  lensActive
                      ? t['graph_lens_count_filtered']!
                          .replaceAll('{visible}', '$visibleCount')
                          .replaceAll('{total}', '$rangeCount')
                      : t['graph_lens_count_all']!.replaceAll('{total}', '$rangeCount'),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final option in GraphContextLens.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(
                        option.icon,
                        size: 16,
                        color: option == lens ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                      ),
                      label: Text(
                        option.labelFor(localeCode, t),
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: option == lens,
                      onSelected: (_) => onLensChanged(option),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}

/// 렌즈 변경 + prefs 저장 헬퍼.
void applyGraphContextLens(WidgetRef ref, GraphContextLens lens) {
  ref.read(graphContextLensProvider.notifier).state = lens;
  writeGraphContextLens(ref.read(preferencesProvider), lens);
}
