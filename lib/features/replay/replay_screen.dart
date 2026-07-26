import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/replay_config.dart';
import '../../features/graph/graph_chat_save.dart';
import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../features/replay/replay_gallery_viewer.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/graph_meaning.dart';
import '../../utils/graph_satellite_chips.dart';
import '../../utils/memory_image_memos.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_video_paths.dart';
import 'memory_focus_preview_sheet.dart';
import 'replay_coach_mark.dart';
import 'replay_insight_cards.dart';
import 'replay_insight_section.dart';
import '../pulse/memory_pulse_section.dart';
import '../../widgets/app_empty_state.dart';

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

class _ReplayTimelineViewState extends ConsumerState<ReplayTimelineView> {
  final _scrollController = ScrollController();
  late List<MapEntry<String, List<Memory>>> _months;
  late List<ReplayInsightCard> _insightCards;

  @override
  void initState() {
    super.initState();
    _rebuildSections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showReplayCoachMarkIfNeeded(context, ref);
    });
  }

  @override
  void didUpdateWidget(covariant ReplayTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memories != widget.memories || oldWidget.localeCode != widget.localeCode) {
      _rebuildSections();
    }
  }

  void _rebuildSections() {
    final sortedMemories = [...widget.memories]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final grouped = <String, List<Memory>>{};
    for (final memory in sortedMemories) {
      final key = widget.localeCode == 'ko'
          ? DateFormat('yyyy년 M월', 'ko').format(memory.createdAt)
          : DateFormat('MMMM yyyy', 'en').format(memory.createdAt);
      grouped.putIfAbsent(key, () => []).add(memory);
    }
    _months = grouped.entries.toList()
      ..sort((a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt));
    _insightCards = buildReplayInsightCards(widget.memories, localeCode: widget.localeCode);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      return AppEmptyState(
        icon: Icons.history_rounded,
        title: widget.emptyLabel,
        subtitle: ref.watch(translationsProvider)['empty_hint'],
      );
    }

    final months = _months;
    final insightCards = _insightCards;

    return RefreshIndicator(
      onRefresh: () => ref.read(memoryListProvider.notifier).reload(),
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReplayMonthHeader(title: month, memoryCount: items.length),
              Card(
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
                        children: [
                          for (var itemIndex = 0; itemIndex < items.length; itemIndex++)
                            Padding(
                              padding: EdgeInsets.only(bottom: itemIndex == items.length - 1 ? 0 : 8),
                              child: _buildReplayTile(items[itemIndex]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplayTile(Memory memory) {
    final photoPaths = resolvedFullImagePathsForMemoryId(memory.id, widget.imagePaths);
    final videoPaths = resolvedVideoPathsForMemoryId(memory.id, widget.videoPaths);
    final photoCount = photoPaths.length;
    final memo = displayMemoForMemory(memory, widget.imageMemos, photoCount: photoCount);
    final thumb = primaryMediaThumbForMemoryId(memory.id, widget.imagePaths, widget.videoPaths);
    return _ReplayTile(
      memory: memory,
      photoPaths: photoPaths,
      videoPaths: videoPaths,
      memo: memo,
      localeCode: widget.localeCode,
      onTap: () => _openMemory(context, memory),
      onLongPress: () => showMemoryFocusPreviewSheet(
        context,
        ref,
        memory: memory,
        imagePath: thumb,
        hasVideo: videoPaths.isNotEmpty,
        photoCount: photoCount,
      ),
      onKeywordTap: (keyword) => openGraphKeywordFocus(ref, keyword),
      onOpenGraph: () => openGraphForMemory(ref, memory),
      onAddMedia: () => _openMemoryForMedia(memory),
      onMediaTap: (index) => _openMemoryMediaViewer(memory, initialIndex: index),
      onMediaLongPress: () => _openMemoryForMedia(memory),
    );
  }

  void _openMemoryMediaViewer(Memory memory, {int initialIndex = 0}) {
    showReplayGalleryViewer(
      context,
      memory: memory,
      imagePaths: widget.imagePaths,
      imageMemos: widget.imageMemos,
      videoPaths: widget.videoPaths,
      initialIndex: initialIndex,
      swipeHint: ref.read(translationsProvider)['gallery_swipe_hint'],
    );
  }

  void _openMemoryForMedia(Memory memory) {
    showMemoryDetailSheet(
      context,
      memory,
      imagePaths: widget.imagePaths,
      options: MemoryDetailPresets.full,
    );
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

class _ReplayMedia {
  const _ReplayMedia({this.imagePath, this.isVideo = false, required this.accent});

  final String? imagePath;
  final bool isVideo;
  final Color accent;
}

class _ReplayTile extends ConsumerWidget {
  const _ReplayTile({
    required this.memory,
    this.photoPaths = const [],
    this.videoPaths = const [],
    this.memo = '',
    this.localeCode = 'ko',
    this.onTap,
    this.onLongPress,
    this.onKeywordTap,
    this.onOpenGraph,
    this.onAddMedia,
    this.onMediaTap,
    this.onMediaLongPress,
  });

  final Memory memory;
  final List<String> photoPaths;
  final List<String> videoPaths;
  final String memo;
  final String localeCode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(String keyword)? onKeywordTap;
  final VoidCallback? onOpenGraph;
  final VoidCallback? onAddMedia;
  final void Function(int index)? onMediaTap;
  final VoidCallback? onMediaLongPress;

  List<_ReplayMedia> _mediaItems() {
    final items = <_ReplayMedia>[];
    for (final p in photoPaths) {
      items.add(_ReplayMedia(imagePath: p, accent: memory.categoryColor));
    }
    for (final v in videoPaths) {
      final thumb = thumbPathForVideoFile(v);
      items.add(_ReplayMedia(
        imagePath: (!kIsWeb && File(thumb).existsSync()) ? thumb : (kIsWeb ? thumb : null),
        isVideo: true,
        accent: memory.categoryColor,
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = memoryDisplayTitle(memory, localeCode: localeCode);
    final t = ref.read(translationsProvider);
    final satellites = buildGraphSatelliteChips(
      memory,
      theme.colorScheme,
      localeCode: localeCode,
      maxCount: 4,
      onChipTap: (keyword, _) => onKeywordTap?.call(keyword),
    );
    final media = _mediaItems();

    return RepaintBoundary(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                if (memo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    memo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 156,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ReplayGraphHalf(memory: memory, localeCode: localeCode),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: media.isEmpty
                            ? _ReplayMediaUploadHint(
                                label: t['replay_media_upload_hint']!,
                                accent: memory.categoryColor,
                                onTap: onAddMedia,
                              )
                            : _ReplayMediaGrid(
                                media: media,
                                totalCount: media.length,
                                onAddMedia: onAddMedia,
                                onMediaTap: onMediaTap,
                                onMediaLongPress: onMediaLongPress,
                              ),
                      ),
                    ],
                  ),
                ),
                if (satellites.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, children: satellites),
                ],
                if (onOpenGraph != null) ...[
                  const SizedBox(height: 4),
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 회상 카드 왼쪽 절반 — 해당 기억의 미니 관계도.
class _ReplayGraphHalf extends StatelessWidget {
  const _ReplayGraphHalf({required this.memory, required this.localeCode});

  final Memory memory;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              width: 220,
              child: MemoryFocusMiniGraph(memory: memory, localeCode: localeCode),
            ),
          ),
        ),
      ),
    );
  }
}

/// 회상 카드 오른쪽 절반 — 2행 2열 미디어 그리드.
class _ReplayMediaGrid extends StatelessWidget {
  const _ReplayMediaGrid({
    required this.media,
    required this.totalCount,
    this.onAddMedia,
    this.onMediaTap,
    this.onMediaLongPress,
  });

  final List<_ReplayMedia> media;
  final int totalCount;
  final VoidCallback? onAddMedia;
  final void Function(int index)? onMediaTap;
  final VoidCallback? onMediaLongPress;

  @override
  Widget build(BuildContext context) {
    Widget cell(int index) {
      if (index >= media.length) {
        // 첫 번째 빈 칸은 미디어 추가 버튼, 나머지는 빈 셀.
        final isFirstEmpty = index == media.length;
        return _ReplayMediaEmptyCell(
          onAddMedia: isFirstEmpty ? onAddMedia : null,
        );
      }
      final extra = (index == 3 && totalCount > 4) ? totalCount - 4 : 0;
      return _ReplayMediaCell(
        media: media[index],
        extraCount: extra,
        onTap: () => onMediaTap?.call(index),
        onLongPress: onMediaLongPress,
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(0)),
              const SizedBox(width: 4),
              Expanded(child: cell(1)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(2)),
              const SizedBox(width: 4),
              Expanded(child: cell(3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReplayMediaCell extends StatelessWidget {
  const _ReplayMediaCell({
    required this.media,
    this.extraCount = 0,
    this.onTap,
    this.onLongPress,
  });

  final _ReplayMedia media;
  final int extraCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final path = media.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (path != null)
            kIsWeb
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                    errorBuilder: (_, _, _) => _fallback(),
                  )
          else
            _fallback(),
          if (media.isVideo)
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
            ),
          if (extraCount > 0)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: media.accent.withValues(alpha: 0.18),
      child: Icon(
        media.isVideo ? Icons.videocam_rounded : Icons.image_outlined,
        color: media.accent,
        size: 22,
      ),
    );
  }
}

class _ReplayMediaEmptyCell extends StatelessWidget {
  const _ReplayMediaEmptyCell({this.onAddMedia});

  final VoidCallback? onAddMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = onAddMedia != null;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: canAdd ? 0.45 : 0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onAddMedia,
        borderRadius: BorderRadius.circular(8),
        child: canAdd
            ? Center(
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  size: 22,
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

/// 미디어가 없을 때 오른쪽 절반에 표시되는 업로드 안내.
class _ReplayMediaUploadHint extends StatelessWidget {
  const _ReplayMediaUploadHint({
    required this.label,
    required this.accent,
    this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DottedBorderBox(
          color: theme.colorScheme.outlineVariant,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: accent, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
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

/// 점선 테두리 컨테이너 (업로드 힌트용).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
