import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/replay_config.dart';
import '../../features/graph/graph_chat_save.dart';
import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../features/memory/memory_media_hero.dart';
import '../../features/replay/replay_gallery_viewer.dart';
import '../../features/replay/replay_parallax.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/graph_satellite_chips.dart';
import '../../utils/memory_image_memos.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_video_paths.dart';
import 'memory_focus_preview_sheet.dart';
import 'replay_coach_mark.dart';
import 'replay_insight_cards.dart';
import 'replay_insight_section.dart';
import '../pulse/memory_pulse_section.dart';

/// 월별로 기억을 묶어 사진 썸네일과 함께 보여줍니다.
class ReplayScreen extends ConsumerWidget {
  const ReplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    return ReplayTimelineView(
      memories: ref.watch(memoryListProvider).where(isUserFacingMemory).toList(),
      imagePaths: ref.watch(memoryImagePathsProvider),
      imageMemos: ref.watch(memoryImageMemosProvider),
      videoPaths: ref.watch(memoryVideoPathsProvider),
      localeCode: ref.watch(languageProvider).languageCode,
      emptyLabel: t['no_memories']!,
    );
  }
}

class ReplayTimelineView extends ConsumerStatefulWidget {
  const ReplayTimelineView({
    super.key,
    required this.memories,
    required this.imagePaths,
    required this.imageMemos,
    required this.videoPaths,
    required this.localeCode,
    required this.emptyLabel,
  });

  final List<Memory> memories;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> imageMemos;
  final Map<String, List<String>> videoPaths;
  final String localeCode;
  final String emptyLabel;

  @override
  ConsumerState<ReplayTimelineView> createState() => _ReplayTimelineViewState();
}

class _ReplayTimelineViewState extends ConsumerState<ReplayTimelineView> with ReplayParallaxController {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        refreshParallaxSections(context);
        showReplayCoachMarkIfNeeded(context, ref);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() => refreshParallaxSections(context);

  void _openMemory(BuildContext context, Memory memory) {
    final mode = ref.read(replayViewModeProvider);
    switch (mode) {
      case ReplayViewMode.gallery:
        showReplayGalleryViewer(
          context,
          memory: memory,
          imagePaths: widget.imagePaths,
          imageMemos: widget.imageMemos,
          videoPaths: widget.videoPaths,
          swipeHint: ref.read(translationsProvider)['gallery_swipe_hint'],
        );
      case ReplayViewMode.light:
        showMemoryDetailSheet(
          context,
          memory,
          imagePaths: widget.imagePaths,
          options: MemoryDetailPresets.replayLight,
          sheetHorizontalMargin: kReplaySheetHorizontalMargin,
          contentHorizontalPadding: kReplaySheetContentPadding,
        );
      case ReplayViewMode.shared:
        showMemoryDetailSheet(
          context,
          memory,
          imagePaths: widget.imagePaths,
          options: MemoryDetailPresets.replayShared,
          sheetHorizontalMargin: kReplaySheetHorizontalMargin,
          contentHorizontalPadding: kReplaySheetContentPadding,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(replayViewModeProvider);
    if (widget.memories.isEmpty) {
      return Center(child: Text(widget.emptyLabel));
    }

    final sortedMemories = [...widget.memories]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final grouped = <String, List<Memory>>{};
    for (final memory in sortedMemories) {
      final key = widget.localeCode == 'ko'
          ? DateFormat('yyyy년 M월', 'ko').format(memory.createdAt)
          : DateFormat('MMMM yyyy', 'en').format(memory.createdAt);
      grouped.putIfAbsent(key, () => []).add(memory);
    }

    final months = grouped.entries.toList()
      ..sort((a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt));

    final insightCards = buildReplayInsightCards(widget.memories, localeCode: widget.localeCode);

    return RefreshIndicator(
      onRefresh: () => ref.read(memoryListProvider.notifier).reload(),
      child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification || notification is ScrollEndNotification) {
          refreshParallaxSections(context);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: months.length + (insightCards.isNotEmpty ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return MemoryPulseSection(
              memories: widget.memories,
              imagePaths: widget.imagePaths,
              videoPaths: widget.videoPaths,
              localeCode: widget.localeCode,
            );
          }
          if (insightCards.isNotEmpty && index == 1) {
            return ReplayInsightSection(cards: insightCards, localeCode: widget.localeCode);
          }
          final monthIndex = insightCards.isNotEmpty ? index - 2 : index - 1;
          final month = months[monthIndex].key;
          final items = months[monthIndex].value;
          final sectionKey = keyForSection(monthIndex);

          return ReplayParallaxSection(
            key: sectionKey,
            sectionKey: index,
            header: _ReplayMonthHeader(title: month, memoryCount: items.length),
            content: Card(
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: monthIndex == 0,
                title: Text(
                  widget.localeCode == 'ko' ? '기억 ${items.length}개' : '${items.length} memories',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 16),
                    child: Column(
                      children: items
                          .map(
                            (memory) {
                              final thumb = primaryMediaThumbForMemoryId(
                                memory.id,
                                widget.imagePaths,
                                widget.videoPaths,
                              );
                              final photoCount = imageCountForMemoryId(memory.id, widget.imagePaths);
                              final hasVideo = memoryHasVideo(memory.id, widget.videoPaths);
                              final memo = displayMemoForMemory(
                                memory,
                                widget.imageMemos,
                                photoCount: photoCount,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ReplayTile(
                                  memory: memory,
                                  imagePath: thumb,
                                  photoCount: photoCount,
                                  photoCountLabel: photoCount > 1 ? _photoCountLabel(photoCount) : null,
                                  memo: memo,
                                  hasVideo: hasVideo,
                                  localeCode: widget.localeCode,
                                  onTap: () => _openMemory(context, memory),
                                  onLongPress: () => showMemoryFocusPreviewSheet(
                                    context,
                                    ref,
                                    memory: memory,
                                    imagePath: thumb,
                                    hasVideo: hasVideo,
                                    photoCount: photoCount,
                                  ),
                                  onKeywordTap: (keyword) => openGraphKeywordFocus(ref, keyword),
                                  onOpenGraph: () => openGraphForMemory(ref, memory),
                                ),
                              );
                            },
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  String _photoCountLabel(int count) {
    return widget.localeCode == 'ko' ? '$count장' : '$count photos';
  }
}

class _ReplayMonthHeader extends StatelessWidget {
  const _ReplayMonthHeader({required this.title, required this.memoryCount});

  final String title;
  final int memoryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$memoryCount',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplayTile extends ConsumerWidget {
  const _ReplayTile({
    required this.memory,
    this.imagePath,
    this.photoCount = 0,
    this.photoCountLabel,
    this.memo = '',
    this.hasVideo = false,
    this.localeCode = 'ko',
    this.onTap,
    this.onLongPress,
    this.onKeywordTap,
    this.onOpenGraph,
  });

  final Memory memory;
  final String? imagePath;
  final int photoCount;
  final String? photoCountLabel;
  final String memo;
  final bool hasVideo;
  final String localeCode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String keyword)? onKeywordTap;
  final VoidCallback? onOpenGraph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = imagePath != null && File(imagePath!).existsSync();
    final title = memory.summary.isNotEmpty ? memory.summary : memory.content;
    final t = ref.watch(translationsProvider);
    final satellites = buildGraphSatelliteChips(
      memory,
      Theme.of(context).colorScheme,
      localeCode: localeCode,
      maxCount: 5,
      onChipTap: (keyword, _) => onKeywordTap?.call(keyword),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    if (hasImage)
                      MemoryMediaHeroImage(
                        memoryId: memory.id,
                        photoIndex: 0,
                        path: imagePath!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        color: memory.categoryColor.withValues(alpha: 0.2),
                        child: Icon(Icons.auto_awesome, color: memory.categoryColor),
                      ),
                    if (photoCount > 1)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: BouncingPhotoCountBadge(
                          count: photoCount,
                          label: photoCountLabel,
                          style: BouncingPhotoCountBadgeStyle.pill,
                        ),
                      ),
                    if (hasVideo)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _ReplayVideoBadge(accent: memory.categoryColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (memo.isNotEmpty) ...[
                Text(
                  memo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (satellites.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 4, children: satellites),
              ],
              if (onOpenGraph != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenGraph,
                    icon: const Icon(Icons.hub_outlined, size: 16),
                    label: Text(t['graph'] ?? '관계망'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                if (onLongPress != null && t['replay_graph_long_press_hint'] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      t['replay_graph_long_press_hint']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayVideoBadge extends StatelessWidget {
  const _ReplayVideoBadge({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.62),
                accent.withValues(alpha: 0.56),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.33), width: 0.7),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
              SizedBox(width: 1),
              Text(
                'VID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
