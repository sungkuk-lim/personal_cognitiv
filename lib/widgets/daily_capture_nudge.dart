import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../features/graph/graph_chat_save.dart';
import '../models/memory.dart';
import '../providers/app_providers.dart';

/// 오늘 기억이 없을 때 타임라인 상단에 표시 — 습관 형성.
class DailyCaptureNudge extends ConsumerStatefulWidget {
  const DailyCaptureNudge({super.key, required this.memories, this.onCaptureTap});

  final List<Memory> memories;
  final VoidCallback? onCaptureTap;

  @override
  ConsumerState<DailyCaptureNudge> createState() => _DailyCaptureNudgeState();
}

class _DailyCaptureNudgeState extends ConsumerState<DailyCaptureNudge> {
  bool _dismissedToday = false;

  bool _hasMemoryToday() {
    final now = DateTime.now();
    for (final memory in widget.memories) {
      if (!isUserFacingMemory(memory)) continue;
      final createdAt = memory.createdAt;
      if (createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasMemoryToday() || _dismissedToday) return const SizedBox.shrink();

    final prefs = ref.read(preferencesProvider);
    final dismissedDay = prefs.getString('daily_nudge_dismissed_day');
    final todayKey = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (dismissedDay == todayKey) return const SizedBox.shrink();

    final t = ref.watch(translationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          onTap: widget.onCaptureTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.wb_twilight_rounded, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['daily_nudge_title']!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        t['daily_nudge_body']!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t['close']!,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () async {
                    await prefs.setString('daily_nudge_dismissed_day', todayKey);
                    if (mounted) setState(() => _dismissedToday = true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
