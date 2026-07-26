import 'dart:io';

import 'package:flutter/material.dart';

/// 썸네일 ↔ 전체 화면 갤러리 Hero 태그.
String memoryMediaHeroTag(String memoryId, int photoIndex) => 'memory_media_${memoryId}_$photoIndex';

/// Hero 전환용 사진 (Material 래핑 필수).
class MemoryMediaHeroImage extends StatelessWidget {
  const MemoryMediaHeroImage({
    super.key,
    required this.memoryId,
    required this.photoIndex,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.useHero = true,
  });

  final String memoryId;
  final int photoIndex;
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final resolvedCacheWidth = cacheWidth ??
        ((width != null && width!.isFinite)
            ? (width! * dpr).round().clamp(128, 960)
            : null);

    Widget image = Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: resolvedCacheWidth,
      filterQuality: filterQuality,
      errorBuilder: (_, _, _) => _brokenPlaceholder(width, height),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    if (!useHero) return image;

    return Hero(
      tag: memoryMediaHeroTag(memoryId, photoIndex),
      child: Material(
        type: MaterialType.transparency,
        child: image,
      ),
    );
  }

  Widget _brokenPlaceholder(double? w, double? h) {
    return SizedBox(
      width: w,
      height: h,
      child: const ColoredBox(
        color: Color(0x22000000),
        child: Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
    );
  }
}

/// 다장 사진 배지 — 등장 시 짧은 scale bounce.
class BouncingPhotoCountBadge extends StatefulWidget {
  const BouncingPhotoCountBadge({
    super.key,
    required this.count,
    this.label,
    this.style = BouncingPhotoCountBadgeStyle.compact,
    this.animated = true,
  });

  final int count;
  final String? label;
  final BouncingPhotoCountBadgeStyle style;
  final bool animated;

  @override
  State<BouncingPhotoCountBadge> createState() => _BouncingPhotoCountBadgeState();
}

enum BouncingPhotoCountBadgeStyle { compact, pill }

class _BouncingPhotoCountBadgeState extends State<BouncingPhotoCountBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 1.14), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animated) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 1) return const SizedBox.shrink();

    final text = widget.label ?? '+${widget.count - 1}';
    final decoration = switch (widget.style) {
      BouncingPhotoCountBadgeStyle.compact => BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
      BouncingPhotoCountBadgeStyle.pill => BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
    };
    final textStyle = switch (widget.style) {
      BouncingPhotoCountBadgeStyle.compact =>
        const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      BouncingPhotoCountBadgeStyle.pill =>
        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
    };
    final padding = switch (widget.style) {
      BouncingPhotoCountBadgeStyle.compact => const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      BouncingPhotoCountBadgeStyle.pill => const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    };

    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: padding,
        decoration: decoration,
        child: Text(text, style: textStyle),
      ),
    );
  }
}
