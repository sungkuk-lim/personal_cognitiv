import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/system_ui.dart';

import '../../models/memory.dart';
import '../../utils/memory_image_memos.dart';
import '../../utils/memory_image_paths.dart';
import '../../utils/memory_video_paths.dart';
import 'local_video_player.dart';
import 'memory_media_hero.dart';

/// 기억의 사진·동영상을 기기 전체 화면에서 좌우 스와이프로 봅니다.
void showMemoryMediaViewer(
  BuildContext context, {
  required Memory memory,
  required Map<String, List<String>> imagePaths,
  required Map<String, List<String>> imageMemos,
  required Map<String, List<String>> videoPaths,
  int initialIndex = 0,
  String? swipeHint,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _MemoryMediaViewer(
            memory: memory,
            imagePaths: imagePaths,
            imageMemos: imageMemos,
            videoPaths: videoPaths,
            initialIndex: initialIndex,
            swipeHint: swipeHint,
          ),
        );
      },
    ),
  );
}

class _MemoryMediaViewer extends StatefulWidget {
  const _MemoryMediaViewer({
    required this.memory,
    required this.imagePaths,
    required this.imageMemos,
    required this.videoPaths,
    required this.initialIndex,
    this.swipeHint,
  });

  final Memory memory;
  final Map<String, List<String>> imagePaths;
  final Map<String, List<String>> imageMemos;
  final Map<String, List<String>> videoPaths;
  final int initialIndex;
  final String? swipeHint;

  @override
  State<_MemoryMediaViewer> createState() => _MemoryMediaViewerState();
}

class _MemoryMediaViewerState extends State<_MemoryMediaViewer> {
  late final PageController _pageController;
  late final List<_MediaSlide> _slides;
  var _current = 0;
  var _playingVideo = false;
  var _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _slides = _buildSlides();
    final start = widget.initialIndex.clamp(0, _slides.isEmpty ? 0 : _slides.length - 1);
    _current = start;
    _pageController = PageController(initialPage: start);
    hideStatusBarForImmersiveViewer();
  }

  @override
  void dispose() {
    ensureStatusBarVisible();
    _pageController.dispose();
    super.dispose();
  }

  List<_MediaSlide> _buildSlides() {
    final slides = <_MediaSlide>[];
    final photos = resolvedFullImagePathsForMemoryId(widget.memory.id, widget.imagePaths);
    final memos = photoMemosForMemoryId(
      widget.memory.id,
      widget.imageMemos,
      memory: widget.memory,
      photoCount: photos.length,
    );
    for (var i = 0; i < photos.length; i++) {
      slides.add(_MediaSlide.photo(photos[i], i < memos.length ? memos[i] : ''));
    }
    for (final video in resolvedVideoPathsForMemoryId(widget.memory.id, widget.videoPaths)) {
      slides.add(_MediaSlide.video(video));
    }
    return slides;
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.photo_library_outlined, color: Colors.white38, size: 56),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final slide = _slides[_current];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              if (index != _current) {
                HapticFeedback.lightImpact();
              }
              setState(() {
                _current = index;
                _playingVideo = false;
              });
            },
            itemBuilder: (context, index) {
              final item = _slides[index];
              if (item.isVideo) {
                return GestureDetector(
                  onTap: _toggleChrome,
                  child: _VideoSlide(
                    path: item.videoPath!,
                    playing: _playingVideo && index == _current,
                    onPlay: () => setState(() => _playingVideo = true),
                  ),
                );
              }
              return GestureDetector(
                onTap: _toggleChrome,
                child: _PhotoSlide(
                  memoryId: widget.memory.id,
                  photoIndex: index,
                  path: item.photoPath!,
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
                          colors: [
                            Colors.black.withValues(alpha: 0.72),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  '${_current + 1} / ${_slides.length}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_slides.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: (slide.memo.trim().isNotEmpty ? 72 : 24) + bottomInset,
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
                            children: List.generate(_slides.length, (i) {
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
                  if (slide.memo.trim().isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.88),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          slide.memo.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
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

class _PhotoSlide extends StatelessWidget {
  const _PhotoSlide({
    required this.memoryId,
    required this.photoIndex,
    required this.path,
  });

  final String memoryId;
  final int photoIndex;
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
          photoIndex: photoIndex,
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

class _VideoSlide extends StatelessWidget {
  const _VideoSlide({
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
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(40),
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSlide {
  const _MediaSlide._({this.photoPath, this.videoPath, this.memo = ''});

  factory _MediaSlide.photo(String path, String memo) => _MediaSlide._(photoPath: path, memo: memo);
  factory _MediaSlide.video(String path) => _MediaSlide._(videoPath: path);

  final String? photoPath;
  final String? videoPath;
  final String memo;

  bool get isVideo => videoPath != null;
}
