import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 기기에 저장된 동영상만 재생합니다. (클라우드 업로드 없음)
class LocalVideoPlayer extends StatefulWidget {
  const LocalVideoPlayer({
    super.key,
    required this.videoPath,
    this.autoPlay = false,
    this.height = 220,
  });

  final String videoPath;
  final bool autoPlay;
  final double height;

  @override
  State<LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<LocalVideoPlayer> {
  VideoPlayerController? _controller;
  var _initialized = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant LocalVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _init();
    }
  }

  Future<void> _init() async {
    if (!File(widget.videoPath).existsSync()) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.file(File(widget.videoPath));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initialized = true);
      if (widget.autoPlay) {
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _failed = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Icon(Icons.videocam_off_outlined)),
      );
    }
    if (!_initialized || _controller == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final controller = _controller!;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
                if (!controller.value.isPlaying)
                  IconButton.filled(
                    iconSize: 48,
                    onPressed: () => controller.play(),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
              ],
            ),
          ),
        ),
        VideoProgressIndicator(controller, allowScrubbing: true),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              },
              icon: Icon(controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
