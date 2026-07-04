import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/memory/local_video_player.dart';
import '../../features/memory/media_delete_button.dart';
import '../../features/memory/memory_detail_options.dart';
import '../../features/memory/memory_detail_presets.dart';
import '../../features/memory/memory_media_viewer.dart';
import '../../features/memory/memory_media_hero.dart';
import '../../features/memory/photo_pick_flow.dart';
import '../../features/graph/graph_chat_save.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../services/image_pipeline_service.dart';
import '../../services/video_pipeline_service.dart';
import '../../utils/memory_image_memos.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_content_edit.dart';
import '../../utils/memory_detail_text.dart';
import '../../utils/memory_place_cache.dart';
import '../../utils/memory_video_paths.dart';
import '../../widgets/trust_source_badge.dart';
import '../../utils/memory_theme_tags.dart';
import '../../utils/ocr_utils.dart';
import '../../features/replay/entity_highlight_viewer.dart';
import '../../utils/entity_highlight_media.dart';
import 'memory_related_section.dart';

/// 메인 탭 하단 네비게이션 높이 — 상세 시트가 가려지지 않도록 패딩에 사용.
const double kMainNavBarSheetInset = 78;

/// 타임라인 카드와 동일 우선순위로 상세 본문 텍스트를 고릅니다.
String memoryDetailBodyText(Memory memory) => memoryDetailBodyTextFromRaw(memory);

/// 회상 목록·카드와 상세 시트 가로 정렬 (리스트 16 + 카드 내부 5).
const double kReplaySheetHorizontalMargin = 16;
const double kReplaySheetContentPadding = 5;

void showMemoryDetailSheet(
  BuildContext context,
  Memory memory, {
  Map<String, List<String>>? imagePaths,
  MemoryDetailOptions options = MemoryDetailPresets.full,
  double sheetHorizontalMargin = 0,
  double contentHorizontalPadding = 24,
}) {
  final useInset = sheetHorizontalMargin > 0;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: useInset ? Colors.transparent : null,
    shape: useInset
        ? null
        : const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        sheetHorizontalMargin,
        0,
        sheetHorizontalMargin,
        kMainNavBarSheetInset,
      ),
      child: Material(
        clipBehavior: useInset ? Clip.antiAlias : Clip.none,
        borderRadius: useInset ? const BorderRadius.vertical(top: Radius.circular(24)) : null,
        color: useInset ? Theme.of(context).colorScheme.surface : null,
        child: _MemoryDetailSheet(
          memory: memory,
          imagePaths: imagePaths,
          options: options,
          contentHorizontalPadding: contentHorizontalPadding,
        ),
      ),
    ),
  );
}

class _MemoryDetailSheet extends ConsumerStatefulWidget {
  const _MemoryDetailSheet({
    required this.memory,
    this.imagePaths,
    this.options = MemoryDetailPresets.full,
    this.contentHorizontalPadding = 24,
  });

  final Memory memory;
  final Map<String, List<String>>? imagePaths;
  final MemoryDetailOptions options;
  final double contentHorizontalPadding;

  @override
  ConsumerState<_MemoryDetailSheet> createState() => _MemoryDetailSheetState();
}

class _MemoryDetailSheetState extends ConsumerState<_MemoryDetailSheet> {
  bool _addingPhoto = false;
  bool _addingVideo = false;

  Memory get _memory {
    final list = ref.watch(memoryListProvider);
    final anchorRaw = widget.options.graphMediaAnchorNodeId?.trim();
    if (anchorRaw != null && anchorRaw.isNotEmpty && isEntityGraphMediaAnchor(anchorRaw)) {
      final anchorId = canonicalGraphAnchorNodeId(anchorRaw);
      for (final memory in list) {
        if (graphNoteAnchorNodeId(memory) == anchorId) return memory;
      }
    }
    return list.firstWhere((m) => m.id == widget.memory.id, orElse: () => widget.memory);
  }

  Future<String> _resolveMediaMemoryId() async {
    final anchorRaw = widget.options.graphMediaAnchorNodeId?.trim();
    if (anchorRaw == null || anchorRaw.isEmpty) return _memory.id;

    if (anchorRaw.startsWith('memory_')) {
      return anchorRaw.replaceFirst('memory_', '');
    }
    if (anchorRaw.startsWith('event_hub_')) {
      return anchorRaw.replaceFirst('event_hub_', '');
    }
    if (anchorRaw.startsWith('entity_note_')) {
      return anchorRaw.replaceFirst('entity_note_', '');
    }
    if (!isEntityGraphMediaAnchor(anchorRaw)) return _memory.id;

    final anchorId = canonicalGraphAnchorNodeId(anchorRaw);
    final memories = ref.read(memoryListProvider);
    for (final memory in memories) {
      if (graphNoteAnchorNodeId(memory) == anchorId) return memory.id;
    }

    final localeCode = ref.read(languageProvider).languageCode;
    final label = graphAnchorLabelFromNodeId(anchorId);
    final primaries = memories.where(isLayoutPrimaryMemory).toList();
    final related = inferPrimaryMemoryForGraphAnchor(label, primaries);
    final draft = buildMediaOnlyGraphNote(
      anchorNodeId: anchorId,
      anchorLabel: label,
      localeCode: localeCode,
      relatedMemoryId: related?.id,
    );
    final saved = await ref.read(memoryListProvider.notifier).addMemory(draft);
    return saved?.id ?? draft.id;
  }

  String? _entityHighlightLabel() {
    final anchorRaw = widget.options.graphMediaAnchorNodeId?.trim();
    if (anchorRaw == null || anchorRaw.isEmpty || !isEntityGraphMediaAnchor(anchorRaw)) return null;
    return graphAnchorLabelFromNodeId(canonicalGraphAnchorNodeId(anchorRaw));
  }

  void _playEntityHighlightFromSheet() {
    final label = _entityHighlightLabel();
    if (label == null || label.isEmpty) return;
    launchEntityHighlight(context: context, ref: ref, entityLabel: label);
  }

  Future<void> _addPhoto() async {
    if (_addingPhoto || !widget.options.allowAddPhoto) return;
    final t = ref.read(translationsProvider);
    final source = await showPhotoSourceSheet(context, t);
    if (source == null || !mounted) return;

    final isEntityMedia = widget.options.graphMediaAnchorNodeId?.trim().isNotEmpty == true;
    if (isEntityMedia && source == ImageSource.gallery) {
      await _addPhotosFromGalleryMulti();
      return;
    }

    setState(() => _addingPhoto = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;

      final bytes = await prepareOcrImageBytes(image, maxSide: fullImageMaxSide, jpegQuality: 88);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['photo_prepare_failed']!)));
        }
        return;
      }

      if (!mounted) return;
      final memo = await showAddPhotoMemoDialog(context, t);
      if (!mounted) return;

      final targetId = await _resolveMediaMemoryId();
      final ok = await appendPhotoToExistingMemory(
        ref: ref,
        memoryId: targetId,
        jpegBytes: bytes,
        additionalMemo: memo ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? t['photo_added']! : t['photo_add_failed']!)),
      );
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  Future<void> _addPhotosFromGalleryMulti() async {
    if (_addingPhoto) return;
    final t = ref.read(translationsProvider);
    setState(() => _addingPhoto = true);
    try {
      final picks = await ImagePicker().pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
        limit: 20,
      );
      if (picks.isEmpty || !mounted) return;

      final targetId = await _resolveMediaMemoryId();
      var okCount = 0;
      final seenPaths = <String>{};
      for (final image in picks) {
        if (!seenPaths.add(image.path)) continue;
        final bytes = await prepareOcrImageBytes(image, maxSide: fullImageMaxSide, jpegQuality: 88);
        if (bytes == null || bytes.isEmpty) continue;
        final ok = await appendPhotoToExistingMemory(
          ref: ref,
          memoryId: targetId,
          jpegBytes: bytes,
          additionalMemo: '',
        );
        if (ok) okCount++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            okCount > 0
                ? t['photos_added_count']!.replaceAll('{count}', '$okCount')
                : t['photo_add_failed']!,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  Future<void> _addVideo() async {
    if (_addingVideo || !widget.options.allowAddVideo) return;
    final t = ref.read(translationsProvider);
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() => _addingVideo = true);
    try {
      final targetId = await _resolveMediaMemoryId();
      final path = await appendMemoryVideo(ref: ref, memoryId: targetId, picked: picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path != null ? t['video_added']! : t['video_add_failed']!)),
      );
      if (path != null) {
        final anchorMemory = _memory;
        if (anchorMemory.type != 'image' && !isGraphAnchorMediaStorage(anchorMemory)) {
          await ref.read(memoryListProvider.notifier).updateMemory(anchorMemory.copyWith(type: 'image'));
        }
      }
    } finally {
      if (mounted) setState(() => _addingVideo = false);
    }
  }

  Future<void> _deletePhoto(int index) async {
    if (!widget.options.allowDeletePhoto) return;
    final t = ref.read(translationsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t['delete_photo_confirm_title']!),
        content: Text(t['delete_photo_confirm_body']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t['cancel']!)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t['delete']!)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final deleted = await removePhotoAtIndex(ref: ref, memoryId: _memory.id, index: index);
    if (mounted && deleted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t['photo_deleted']!)));
    }
  }

  Future<void> _deleteVideo(int index) async {
    if (!widget.options.allowDeleteVideo) return;
    final t = ref.read(translationsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t['delete_video_confirm_title']!),
        content: Text(t['delete_video_confirm_body']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t['cancel']!)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t['delete']!)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await removeVideoAtIndex(ref: ref, memoryId: _memory.id, index: index);
  }

  Future<void> _editSummary(Memory memory) async {
    final t = ref.read(translationsProvider);
    final controller = TextEditingController(text: memory.summary);
    final newSummary = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(t['edit_summary'] ?? '요약 수정'),
        content: SizedBox(
          width: double.maxFinite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t['cancel']!)),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t['save'] ?? '저장'),
          ),
        ],
      ),
    );
    if (newSummary != null && newSummary != memory.summary && mounted) {
      await ref.read(memoryListProvider.notifier).updateMemory(memory.copyWith(summary: newSummary));
    }
  }

  Future<void> _editContent(Memory memory) async {
    final t = ref.read(translationsProvider);
    final graphMarker = t['graph_node_ai_save_marker']!;
    final previousBody = memoryEditDisplayBody(memory, graphMarkerLabel: graphMarker);
    final controller = TextEditingController(text: previousBody);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(t['edit_content'] ?? '내용 수정'),
        content: SizedBox(
          width: double.maxFinite,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t['cancel']!)),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t['save'] ?? '저장'),
          ),
        ],
      ),
    );
    if (newContent != null && newContent.trim() != previousBody.trim() && mounted) {
      final patched = applyMemoryContentEdit(
        memory: memory,
        newMainText: newContent,
        previousBodyText: previousBody,
        graphMarkerLabel: graphMarker,
      );
      await ref.read(memoryListProvider.notifier).updateMemory(patched);
    }
  }

  void _openMediaViewer({required int initialIndex}) {
    final t = ref.read(translationsProvider);
    showMemoryMediaViewer(
      context,
      memory: _memory,
      imagePaths: ref.read(memoryImagePathsProvider),
      imageMemos: ref.read(memoryImageMemosProvider),
      videoPaths: ref.read(memoryVideoPathsProvider),
      initialIndex: initialIndex,
      swipeHint: t['gallery_swipe_hint'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final memory = _memory;
    final opts = widget.options;
    final pathsMap = ref.watch(memoryImagePathsProvider);
    final memosMap = ref.watch(memoryImageMemosProvider);
    final videoMap = ref.watch(memoryVideoPathsProvider);
    final placeCache = ref.watch(memoryPlaceNamesProvider);
    final fullAddressCache = ref.watch(memoryPlaceFullAddressesProvider);
    final allMemories = ref.watch(memoryListProvider);
    final localeCode = ref.watch(languageProvider).languageCode;
    final photos = resolvedFullImagePathsForMemoryId(memory.id, pathsMap);
    final videos = resolvedVideoPathsForMemoryId(memory.id, videoMap);
    final photoMemos = photoMemosForMemoryId(memory.id, memosMap, memory: memory, photoCount: photos.length);
    final title = isGraphNoteMemory(memory)
        ? ''
        : (memory.type == 'image' && isJunkEntityOrKeyword(memory.summary)
            ? graphTitleForMemory(memory)
            : memory.summary);
    final bodyParts = splitMemoryBodyForDisplay(
      memory,
      graphMarkerLabel: t['graph_node_ai_save_marker']!,
    );
    final bodyText = isGraphNoteMemory(memory)
        ? graphNoteDetailBody(memory)
        : (bodyParts.mainText.isNotEmpty
            ? bodyParts.mainText
            : memoryDetailDisplayBody(memory));
    final graphNoteAnchor = graphNoteAnchorLabel(memory);
    final showTitleLine = shouldShowMemoryDetailSummaryTitle(
      summaryTitle: title,
      bodyText: bodyText,
    );
    var placeTitle = displayPlaceAddress(
      memory,
      placeCache,
      fullAddressCache,
      localeCode: localeCode,
      allMemories: allMemories,
    );
    if (!isGraphNoteMemory(memory) &&
        (memoryTextsOverlapForDisplay(placeTitle, title) ||
            memoryTextsOverlapForDisplay(placeTitle, bodyText))) {
      final fromEntity = placeLabelFromEntities(memory);
      placeTitle = fromEntity ?? (localeCode == 'ko' ? '장소 미상' : 'Unknown place');
      if (memoryTextsOverlapForDisplay(placeTitle, title) ||
          memoryTextsOverlapForDisplay(placeTitle, bodyText)) {
        placeTitle = '';
      }
    }
    if (isGraphNoteMemory(memory) && isGraphNotePlaceUnknown(placeTitle, localeCode)) {
      placeTitle = '';
    }
    final photoHeight = opts.isLight ? 300.0 : 200.0;
    final hasMedia = photos.isNotEmpty || videos.isNotEmpty;
    final hasText = placeTitle.isNotEmpty || showTitleLine || bodyText.isNotEmpty;
    final videosFirst = opts.autoPlayVideo && videos.isNotEmpty;
    final accent = memory.categoryColor;

    final editable = opts.isEditable;

    List<Widget> mediaChildren() {
      final widgets = <Widget>[];

      void addVideos() {
        for (var i = 0; i < videos.length; i++) {
          widgets.addAll([
            Card(
              margin: EdgeInsets.zero,
              color: accent.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: accent.withValues(alpha: 0.45), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => _openMediaViewer(initialIndex: photos.length + i),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          LocalVideoPlayer(
                            videoPath: videos[i],
                            autoPlay: opts.autoPlayVideo && i == 0,
                            height: photoHeight,
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fullscreen_rounded, color: Colors.white.withValues(alpha: 0.92), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  t['gallery_tap_expand']!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (editable)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: MediaDeleteButton(onPressed: () => _deleteVideo(i)),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: opts.isLight ? 20 : 16),
          ]);
        }
      }

      void addPhotos() {
        for (var i = 0; i < photos.length; i++) {
          widgets.addAll([
            Card(
              margin: EdgeInsets.zero,
              color: accent.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: accent.withValues(alpha: 0.45), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => _openMediaViewer(initialIndex: i),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          MemoryMediaHeroImage(
                            memoryId: memory.id,
                            photoIndex: i,
                            path: photos[i],
                            width: double.infinity,
                            height: photoHeight,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(12),
                            filterQuality: FilterQuality.high,
                            cacheWidth: opts.isLight ? 1600 : 1400,
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fullscreen_rounded, color: Colors.white.withValues(alpha: 0.92), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  t['gallery_tap_expand']!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (editable)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: MediaDeleteButton(onPressed: () => _deletePhoto(i)),
                      ),
                  ],
                ),
              ),
            ),
            if (i < photoMemos.length && photoMemos[i].trim().isNotEmpty) ...[
              SizedBox(height: opts.isLight ? 12 : 8),
              Text(
                photoMemos[i].trim(),
                style: TextStyle(
                  fontSize: opts.isLight ? 17 : 14,
                  height: 1.45,
                  fontWeight: opts.isLight ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
            SizedBox(height: opts.isLight ? 20 : 16),
          ]);
        }
      }

      if (videosFirst) {
        addVideos();
        addPhotos();
      } else {
        addPhotos();
        addVideos();
      }
      return widgets;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: opts.isLight
          ? (hasMedia ? 0.88 : (memory.content.trim().isNotEmpty ? 0.55 : 0.42))
          : _fullModeInitialSheetSize(
              hasMedia: hasMedia,
              hasText: hasText,
              mediaCount: photos.length + videos.length,
            ),
      maxChildSize: 0.92,
      builder: (context, scrollController) => LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(widget.contentHorizontalPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            if (opts.showReturnBar) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: Text(t['detail_back_previous']!),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (_entityHighlightLabel() != null &&
                countEntityHighlightSlides(
                  entityLabel: _entityHighlightLabel()!,
                  allMemories: ref.watch(memoryListProvider),
                  imagePaths: pathsMap,
                  videoPaths: videoMap,
                ) >
                    0) ...[
              FilledButton.tonalIcon(
                onPressed: _playEntityHighlightFromSheet,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: Text(t['entity_highlight_play']!.replaceAll('{name}', _entityHighlightLabel()!)),
              ),
              const SizedBox(height: 10),
            ],
            if (isGraphNoteMemory(memory) && graphNoteAnchor != null && graphNoteAnchor.isNotEmpty) ...[
              _GraphContextBanner(
                icon: Icons.person_pin_circle_outlined,
                message: t['detail_graph_note_banner']!.replaceAll('{anchor}', graphNoteAnchor),
                accent: accent,
              ),
              const SizedBox(height: 10),
            ],
            if (opts.isLight) ...[
              Text(
                placeTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (memory.content.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _editContent(memory),
                  child: Text(
                    bodyText.trim(),
                    style: const TextStyle(fontSize: 18, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              if (bodyParts.appendixText != null) ...[
                const SizedBox(height: 14),
                _GraphAppendixSection(
                  label: t['detail_graph_appendix_label']!,
                  text: bodyParts.appendixText!,
                  accent: accent,
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (!opts.isLight) ...[
              TrustSourceBadge(memory: memory),
              const SizedBox(height: 8),
              _FullModeTextHeader(
                memory: memory,
                title: title,
                bodyText: bodyText,
                appendixLabel: bodyParts.appendixText != null ? t['detail_graph_appendix_label']! : null,
                appendixText: bodyParts.appendixText,
                placeTitle: placeTitle,
                showTitleLine: showTitleLine,
                accent: accent,
                emptyHint: t['detail_empty_body_hint']!,
                onEditSummary: () => _editSummary(memory),
                onEditContent: () => _editContent(memory),
              ),
              const SizedBox(height: 16),
            ],
            ...mediaChildren(),
            if (editable)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addingPhoto ? null : _addPhoto,
                      icon: _addingPhoto
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(t['add_photo']!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addingVideo ? null : _addVideo,
                      icon: _addingVideo
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.videocam_outlined),
                      label: Text(t['add_video']!),
                    ),
                  ),
                ],
              ),
            if (!opts.isLight && displayEntitiesForMemory(memory).isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: displayEntitiesForMemory(memory).map((e) => Chip(label: Text(e))).toList(),
              ),
            ],
            if (!opts.isLight) MemoryRelatedSection(memory: memory),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

double _fullModeInitialSheetSize({
  required bool hasMedia,
  required bool hasText,
  required int mediaCount,
}) {
  if (!hasMedia) return hasText ? 0.42 : 0.35;
  if (!hasText) return mediaCount > 1 ? 0.72 : 0.58;
  return mediaCount > 1 ? 0.82 : 0.72;
}

class _FullModeTextHeader extends StatelessWidget {
  const _FullModeTextHeader({
    required this.memory,
    required this.title,
    required this.bodyText,
    this.appendixLabel,
    this.appendixText,
    required this.placeTitle,
    required this.showTitleLine,
    required this.accent,
    required this.emptyHint,
    required this.onEditSummary,
    required this.onEditContent,
  });

  final Memory memory;
  final String title;
  final String bodyText;
  final String? appendixLabel;
  final String? appendixText;
  final String placeTitle;
  final bool showTitleLine;
  final Color accent;
  final String emptyHint;
  final VoidCallback onEditSummary;
  final VoidCallback onEditContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: accent.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (placeTitle.isNotEmpty) ...[
              Text(
                placeTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
            ],
            if (showTitleLine) ...[
              InkWell(
                onTap: onEditSummary,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    title.trim(),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            InkWell(
              onTap: onEditContent,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  bodyText.isNotEmpty ? bodyText : emptyHint,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: bodyText.isNotEmpty
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontStyle: bodyText.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
            if (appendixText != null && appendixLabel != null) ...[
              const SizedBox(height: 14),
              _GraphAppendixSection(label: appendixLabel!, text: appendixText!, accent: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _GraphContextBanner extends StatelessWidget {
  const _GraphContextBanner({
    required this.icon,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphAppendixSection extends StatelessWidget {
  const _GraphAppendixSection({
    required this.label,
    required this.text,
    required this.accent,
  });

  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
