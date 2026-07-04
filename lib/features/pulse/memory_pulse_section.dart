import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../features/replay/entity_highlight_viewer.dart';
import '../../features/story/relationship_story_screen.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/memory_pulse_service.dart';
import '../../utils/entity_highlight_media.dart';
import '../../utils/memory_video_paths.dart';

/// 회상 탭 상단 — 오늘의 기억 펄스.
class MemoryPulseSection extends ConsumerWidget {
  const MemoryPulseSection({
    super.key,
    required this.memories,
    required this.imagePaths,
    required this.videoPaths,
    required this.localeCode,
  });

  final List<Memory> memories;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> videoPaths;
  final String localeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final offer = buildDailyMemoryPulse(memories, localeCode: localeCode);
    if (offer == null) return const SizedBox.shrink();

    final accent = switch (offer.kind) {
      MemoryPulseKind.onThisDay => const Color(0xFFE91E63),
      MemoryPulseKind.personSpotlight => Colors.deepPurple,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPulse(context, ref, offer),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite_rounded, color: accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['memory_pulse_title']!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_fill_rounded, color: accent, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPulse(BuildContext context, WidgetRef ref, MemoryPulseOffer offer) {
    if (offer.kind == MemoryPulseKind.personSpotlight && offer.entityLabel != null) {
      final label = offer.entityLabel!;
      final slides = countEntityHighlightSlides(
        entityLabel: label,
        allMemories: ref.read(memoryListProvider),
        imagePaths: imagePaths,
        videoPaths: videoPaths,
      );
      if (slides > 0) {
        launchEntityHighlight(context: context, ref: ref, entityLabel: label);
        return;
      }
      RelationshipStoryScreen.open(context, ref, label);
      return;
    }

    if (offer.memories.length == 1) {
      showMemoryDetailSheet(
        context,
        offer.memories.first,
        imagePaths: imagePaths,
        options: MemoryDetailPresets.replayShared,
      );
      return;
    }

    final label = offer.entityLabel ?? offer.memories.first.summary;
    launchEntityHighlight(context: context, ref: ref, entityLabel: label);
  }
}
