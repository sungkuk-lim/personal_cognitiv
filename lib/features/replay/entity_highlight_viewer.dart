import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/system_ui.dart';
import '../../features/graph/graph_layout.dart';
import '../../features/memory/local_video_player.dart';
import '../../features/memory/memory_media_hero.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import '../../utils/entity_highlight_media.dart';
import '../../utils/memory_video_paths.dart';

/// 인물·장소·키워드와 연결된 사진·동영상을 한 흐름으로 재생합니다.
void showEntityHighlightViewer(
  BuildContext context, {
  required String entityLabel,
  required List<EntityHighlightSlide> slides,
  String? swipeHint,
}) {
  if (slides.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _EntityHighlightViewer(
            entityLabel: entityLabel,
            slides: slides,
            swipeHint: swipeHint,
          ),
        );
      },
    ),
  );
}

/// Riverpod에서 미디어를 모아 하이라이트를 실행합니다. 슬라이드가 없으면 false.
bool launchEntityHighlight({
  required BuildContext context,
  required WidgetRef ref,
  required String entityLabel,
  GraphNodeData? node,
  List<GraphEdgeData>? edges,
}) {
  final memories = ref.read(memoryListProvider);
  final imagePaths = ref.read(memoryImagePathsProvider);
  final imageMemos = ref.read(memoryImageMemosProvider);
  final videoPaths = ref.read(memoryVideoPathsProvider);
  final localeCode = ref.read(languageProvider).languageCode;
  final t = ref.read(translationsProvider);

  final slides = collectEntityHighlightSlides(
    entityLabel: entityLabel,
    allMemories: memories,
    imagePaths: imagePaths,
    imageMemos: imageMemos,
    videoPaths: videoPaths,
    node: node,
    edges: edges,
    localeCode: localeCode,
  );
  if (slides.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t['entity_highlight_empty']!)),
    );
    return false;
  }

  showEntityHighlightViewer(
    context,
    entityLabel: entityLabel,
    slides: slides,
    swipeHint: t['entity_highlight_swipe_hint'],
  );
  return true;
}

class _EntityHighlightViewer extends StatefulWidget {
  const _EntityHighlightViewer({
    required this.entityLabel,
    required this.slides,
    this.swipeHint,
  });

  final String entityLabel;
  final List<EntityHighlightSlide> slides;
  final String? swipeHint;

  @override
  State<_EntityHighlightViewer> createState() => _EntityHighlightViewerState();
}

class _EntityHighlightViewerState extends State<_EntityHighlightViewer> {
  late final PageController _pageController;
  var _current = 0;
  var _playingVideo = false;
  var _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _current = 0;
    _pageController = PageController();
    hideStatusBarForImmersiveViewer();
  }

  @override
  void dispose() {
    ensureStatusBarVisible();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[_current];
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final caption = slide.caption.trim().isNotEmpty ? slide.caption.trim() : slide.memoryTitle;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.slides.length,
            onPageChanged: (index) {
              if (index != _current) HapticFeedback.lightImpact();
              setState(() {
                _current = index;
                _playingVideo = false;
              });
            },
            itemBuilder: (context, index) {
              final item = widget.slides[index];
              if (item.isVideo) {
                return GestureDetector(
                  onTap: _toggleChrome,
                  child: _HighlightVideoSlide(
                    path: item.videoPath!,
                    playing: _playingVideo && index == _current,
                    onPlay: () => setState(() => _playingVideo = true),
                  ),
                );
              }
              return GestureDetector(
                onTap: _toggleChrome,
                child: _HighlightPhotoSlide(
                  memoryId: item.memoryId,
                  path: item.imagePath!,
                ),
              );
            },
          ),
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.78), Colors.transparent],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      widget.entityLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_current + 1} / ${widget.slides.length}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.82),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.slides.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: (caption.isNotEmpty ? 88 : 28) + bottomInset,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.swipeHint?.trim().isNotEmpty ?? false) ...[
                            Text(
                              widget.swipeHint!.trim(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.slides.length.clamp(0, 12), (i) {
                              final active = i == _current;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: active ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slide.dateLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (caption.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              caption,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightPhotoSlide extends StatelessWidget {
  const _HighlightPhotoSlide({required this.memoryId, required this.path});

  final String memoryId;
  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48));
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: MemoryMediaHeroImage(
          memoryId: memoryId,
          photoIndex: 0,
          path: path,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _HighlightVideoSlide extends StatelessWidget {
  const _HighlightVideoSlide({
    required this.path,
    required this.playing,
    required this.onPlay,
  });

  final String path;
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    if (playing) {
      return Center(
        child: LocalVideoPlayer(
          videoPath: path,
          autoPlay: true,
          height: MediaQuery.sizeOf(context).height,
        ),
      );
    }
    final thumb = thumbPathForVideoFile(path);
    return GestureDetector(
      onTap: onPlay,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (File(thumb).existsSync())
              Image.file(File(thumb), fit: BoxFit.contain, width: double.infinity, height: double.infinity)
            else
              const Icon(Icons.videocam_outlined, color: Colors.white54, size: 72),
            Container(
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(40)),
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
            ),
          ],
        ),
      ),
    );
  }
}
