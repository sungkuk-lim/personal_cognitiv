import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/graph/graph_chat_save.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/memory_detail_text.dart';
import '../../utils/memory_grouping.dart';
import '../../utils/memory_image_memos.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/memory_keyword_ui.dart';
import '../../utils/memory_place_cache.dart';
import '../../utils/memory_video_paths.dart';
import '../../widgets/trust_source_badge.dart';
import '../../utils/ocr_utils.dart';
import '../../utils/recall_anchor.dart';

/// 같은 날·같은 장소 기억 묶음 카드.
class MemoryGroupCard extends ConsumerWidget {
  const MemoryGroupCard({
    super.key,
    required this.group,
    required this.onTapMemory,
    this.confirmDelete,
    this.onDeleteMemory,
  });

  final MemoryTimelineGroup group;
  final void Function(Memory memory) onTapMemory;
  final Future<bool> Function()? confirmDelete;
  final void Function(Memory memory)? onDeleteMemory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!group.isGrouped) {
      return MemoryCard(memory: group.primary, onTap: () => onTapMemory(group.primary));
    }

    final locale = ref.watch(languageProvider);
    final placeCache = ref.watch(memoryPlaceNamesProvider);
    final fullAddressCache = ref.watch(memoryPlaceFullAddressesProvider);
    final allMemories = ref.watch(memoryListProvider);
    final placeTitle = displayGroupAddress(
      group,
      placeCache,
      fullAddressCache,
      localeCode: locale.languageCode,
      allMemories: allMemories,
    );
    final dateLabel = locale.languageCode == 'ko'
        ? DateFormat('M월 d일', 'ko').format(group.primary.createdAt)
        : DateFormat('MMM d', 'en').format(group.primary.createdAt);
    final accent = colorForMemoryCluster(group.key);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0.06)],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    placeTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: accent),
                  ),
                ),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                for (var i = 0; i < group.memories.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _DismissibleSubMemoryCard(
                    memory: group.memories[i],
                    accent: accent,
                    allMemories: allMemories,
                    onTap: () => onTapMemory(group.memories[i]),
                    confirmDelete: confirmDelete,
                    onDismissed: onDeleteMemory == null
                        ? null
                        : () => onDeleteMemory!(group.memories[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissibleSubMemoryCard extends StatelessWidget {
  const _DismissibleSubMemoryCard({
    required this.memory,
    required this.accent,
    required this.allMemories,
    required this.onTap,
    this.confirmDelete,
    this.onDismissed,
  });

  final Memory memory;
  final Color accent;
  final List<Memory> allMemories;
  final VoidCallback onTap;
  final Future<bool> Function()? confirmDelete;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    if (onDismissed == null) {
      return _SubMemoryCard(
        memory: memory,
        accent: accent,
        allMemories: allMemories,
        onTap: onTap,
      );
    }

    return Dismissible(
      key: Key('timeline_sub_${memory.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete?.call() ?? Future.value(true),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed!(),
      child: _SubMemoryCard(
        memory: memory,
        accent: accent,
        allMemories: allMemories,
        onTap: onTap,
      ),
    );
  }
}

class _SubMemoryCard extends ConsumerWidget {
  const _SubMemoryCard({
    required this.memory,
    required this.accent,
    required this.allMemories,
    required this.onTap,
  });

  final Memory memory;
  final Color accent;
  final List<Memory> allMemories;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final imageMemos = ref.watch(memoryImageMemosProvider);
    final videoPaths = ref.watch(memoryVideoPathsProvider);
    final timeText = DateFormat('HH:mm', locale.languageCode).format(memory.createdAt);
    final thumb = primaryMediaThumbForMemoryId(memory.id, imagePaths, videoPaths);
    final hasVideo = memoryHasVideo(memory.id, videoPaths);
    final photoCount = imageCountForMemoryId(memory.id, imagePaths);
    final isGraphNote = isGraphNoteMemory(memory);
    final cardMemo = isGraphNote ? '' : displayMemoForMemory(memory, imageMemos, photoCount: photoCount);
    final content = isGraphNote
        ? graphNoteCardBody(memory)
        : (memory.content.trim().isNotEmpty ? memory.content.trim() : memory.summary);
    final keywords = buildKeywordChips(
      memory,
      Theme.of(context).colorScheme,
      onKeywordTap: (keyword) => openGraphKeywordFocus(ref, keyword),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final graphNoteBg = isDark
        ? colorScheme.tertiaryContainer.withValues(alpha: 0.55)
        : const Color(0xFFE8F5E9);
    final graphNoteBorder = isDark
        ? colorScheme.tertiary.withValues(alpha: 0.72)
        : const Color(0xFF43A047);
    final graphNoteIcon = isDark ? colorScheme.tertiary : const Color(0xFF2E7D32);
    final graphNoteLabel = isDark ? colorScheme.onTertiaryContainer : const Color(0xFF1B5E20);
    final graphNoteBody = isDark ? colorScheme.onSurface : colorScheme.onSurface;

    return Material(
      color: isGraphNote ? graphNoteBg : accent.withValues(alpha: isDark ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGraphNote ? graphNoteBorder : accent.withValues(alpha: isDark ? 0.4 : 0.28),
              width: isGraphNote ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGraphNote)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      Icon(Icons.hub_outlined, size: 16, color: graphNoteIcon),
                      const SizedBox(width: 6),
                      Text(
                        locale.languageCode == 'ko' ? '관계망 메모' : 'Graph note',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: graphNoteLabel,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeText,
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (thumb != null || hasVideo)
                _MediaThumbnail(
                  thumbPath: thumb,
                  hasVideo: hasVideo,
                  height: 140,
                  accent: accent,
                  compact: true,
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isGraphNote) Text(timeText, style: Theme.of(context).textTheme.labelSmall),
                    if (cardMemo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(cardMemo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    ],
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isGraphNote ? graphNoteBody : null,
                          fontWeight: isGraphNote ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                    if (keywords.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: keywords),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryCard extends ConsumerWidget {
  final Memory memory;
  final VoidCallback? onTap;
  const MemoryCard({super.key, required this.memory, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final locale = ref.watch(languageProvider);
    final placeCache = ref.watch(memoryPlaceNamesProvider);
    final fullAddressCache = ref.watch(memoryPlaceFullAddressesProvider);
    final allMemories = ref.watch(memoryListProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final imageMemos = ref.watch(memoryImageMemosProvider);
    final videoPaths = ref.watch(memoryVideoPathsProvider);
    final localImagePath = primaryMediaThumbForMemoryId(memory.id, imagePaths, videoPaths);
    final photoCount = imageCountForMemoryId(memory.id, imagePaths);
    final hasVideo = memoryHasVideo(memory.id, videoPaths);
    final hasThumbnail = localImagePath != null;
    final showMediaHeader = hasThumbnail || hasVideo;
    final cardMemo = displayMemoForMemory(memory, imageMemos, photoCount: photoCount);
    final categoryLabel = localizedCategoryLabel(t, memory.category);
    final dateText = locale.languageCode == 'ko'
        ? DateFormat('M월 d일 HH:mm', 'ko').format(memory.createdAt)
        : DateFormat('MMM d, HH:mm', 'en').format(memory.createdAt);
    final placeTitle = displayPlaceAddress(
      memory,
      placeCache,
      fullAddressCache,
      localeCode: locale.languageCode,
      allMemories: allMemories,
    );
    final content = isGraphNoteMemory(memory)
        ? graphNoteCardBody(memory)
        : (memory.content.trim().isNotEmpty
            ? memory.content.trim()
            : stripLatLngFromTitle(memory.summary));
    final accent = colorForMemory(memory);
    final keywords = buildKeywordChips(
      memory,
      Theme.of(context).colorScheme,
      onKeywordTap: (keyword) => openGraphKeywordFocus(ref, keyword),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showMediaHeader)
              _MediaThumbnail(
                thumbPath: localImagePath,
                hasVideo: hasVideo,
                height: 200,
                accent: accent,
                photoCount: photoCount,
                localeCode: locale.languageCode,
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(dateText, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 8),
                    TrustSourceBadge(memory: memory, compact: true),
                    const SizedBox(width: 6),
                    _RecallAnchorBadge(memory: memory, localeCode: locale.languageCode, t: t),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$categoryLabel > ${memory.subCategory}',
                        style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                  if (hasThumbnail && cardMemo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      cardMemo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    placeTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (content.isNotEmpty &&
                      !memoryTextsOverlapForDisplay(placeTitle, content) &&
                      content != placeTitle) ...[
                    const SizedBox(height: 6),
                    Text(
                      content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                  if (keywords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: keywords),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.path, required this.height});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      cacheWidth: 1200,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    required this.thumbPath,
    required this.hasVideo,
    required this.height,
    required this.accent,
    this.compact = false,
    this.photoCount = 0,
    this.localeCode = 'ko',
  });

  final String? thumbPath;
  final bool hasVideo;
  final double height;
  final Color accent;
  final bool compact;
  final int photoCount;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final playSize = compact ? 44.0 : 56.0;
    final playIcon = compact ? 28.0 : 34.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (thumbPath != null)
          _CardImage(path: thumbPath!, height: height)
        else if (hasVideo)
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        if (hasVideo)
          Container(
            width: playSize,
            height: playSize,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
            ),
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: playIcon),
          ),
        if (photoCount > 1)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                localeCode == 'ko' ? '$photoCount장' : '$photoCount photos',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecallAnchorBadge extends StatelessWidget {
  const _RecallAnchorBadge({
    required this.memory,
    required this.localeCode,
    required this.t,
  });

  final Memory memory;
  final String localeCode;
  final Map<String, String> t;

  @override
  Widget build(BuildContext context) {
    final status = recallAnchorStatus(memory, localeCode: localeCode);
    final (icon, label, color) = switch (status) {
      RecallAnchorStatus.active => (
          Icons.near_me_rounded,
          t['recall_badge_active']!,
          Colors.blue.shade600,
        ),
      RecallAnchorStatus.needsPlace => (
          Icons.place_outlined,
          t['recall_badge_needs_place']!,
          Colors.orange.shade700,
        ),
      RecallAnchorStatus.disabled => (
          Icons.notifications_off_outlined,
          t['recall_badge_disabled']!,
          Colors.grey.shade600,
        ),
      RecallAnchorStatus.none => (null, null, null),
    };
    if (icon == null || label == null || color == null) return const SizedBox.shrink();

    return Tooltip(
      message: recallAnchorLabel(memory, localeCode: localeCode) ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
