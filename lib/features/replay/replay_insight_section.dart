import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/entity_highlight_media.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../features/story/relationship_story_screen.dart';
import '../replay/entity_highlight_viewer.dart';
import 'replay_insight_cards.dart';

class ReplayInsightSection extends ConsumerWidget {
  const ReplayInsightSection({
    super.key,
    required this.cards,
    required this.localeCode,
  });

  final List<ReplayInsightCard> cards;
  final String localeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final memories = ref.watch(memoryListProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final videoPaths = ref.watch(memoryVideoPathsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['replay_insights_title']!,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (t['replay_insights_hint'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  t['replay_insights_hint']!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final card = cards[i];
              final slideCount = countEntityHighlightSlides(
                entityLabel: card.focusKeyword,
                allMemories: memories,
                imagePaths: imagePaths,
                videoPaths: videoPaths,
              );
              return _InsightChipCard(
                card: card,
                localeCode: localeCode,
                slideCount: slideCount,
                onPlayHighlight: slideCount > 0
                    ? () {
                        HapticFeedback.mediumImpact();
                        launchEntityHighlight(
                          context: context,
                          ref: ref,
                          entityLabel: card.focusKeyword,
                        );
                      }
                    : null,
                onOpenStory: () => RelationshipStoryScreen.open(context, ref, card.focusKeyword),
                onOpenGraph: () => openGraphKeywordFocus(ref, card.focusKeyword),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _InsightChipCard extends StatelessWidget {
  const _InsightChipCard({
    required this.card,
    required this.localeCode,
    required this.slideCount,
    required this.onOpenGraph,
    required this.onOpenStory,
    this.onPlayHighlight,
  });

  final ReplayInsightCard card;
  final String localeCode;
  final int slideCount;
  final VoidCallback? onPlayHighlight;
  final VoidCallback onOpenStory;
  final VoidCallback onOpenGraph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (card.kind) {
      ReplayInsightKind.person => (Icons.person_rounded, Colors.pink.shade400),
      ReplayInsightKind.place => (Icons.place_rounded, Colors.teal.shade500),
      ReplayInsightKind.event => (Icons.event_rounded, const Color(0xFF6750A4)),
      ReplayInsightKind.organization => (Icons.groups_rounded, Colors.indigo.shade400),
      ReplayInsightKind.emotion => (Icons.favorite_rounded, Colors.deepOrange.shade400),
      ReplayInsightKind.food => (Icons.restaurant_rounded, Colors.orange.shade600),
      ReplayInsightKind.hobby => (Icons.interests_rounded, Colors.blue.shade400),
    };

    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPlayHighlight ?? onOpenStory,
        onLongPress: onOpenGraph,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 176,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: color),
                    const SizedBox(width: 6),
                    _CountBadge(count: card.memoryCount, color: color),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(Icons.menu_book_rounded, size: 18, color: color.withValues(alpha: 0.85)),
                      onPressed: onOpenStory,
                      tooltip: localeCode == 'ko' ? '이야기' : 'Story',
                    ),
                    if (onPlayHighlight != null)
                      Icon(Icons.play_circle_fill_rounded, size: 22, color: color),
                  ],
                ),
                const Spacer(),
                Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  slideCount > 0
                      ? (localeCode == 'ko'
                          ? '${card.subtitle} · 사진·동영상 $slideCount'
                          : '${card.subtitle} · $slideCount photos & videos')
                      : card.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
      ),
    );
  }
}
