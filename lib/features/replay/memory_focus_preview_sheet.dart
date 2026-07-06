import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/graph/graph_layout.dart';
import '../../features/memory/memory_media_hero.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../utils/graph_keyword_focus.dart';
import '../../utils/graph_meaning.dart';
import '../../utils/graph_satellite_chips.dart';
import '../../utils/graph_satellite_chips.dart';

/// 회상 카드 롱프레스 — 사진·동영상 + 위성 칩 + 미니 관계망 미리보기.
void showMemoryFocusPreviewSheet(
  BuildContext context,
  WidgetRef ref, {
  required Memory memory,
  String? imagePath,
  bool hasVideo = false,
  int photoCount = 0,
}) {
  final t = ref.read(translationsProvider);
  final localeCode = ref.read(languageProvider).languageCode;
  final theme = Theme.of(context);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final title = graphMeaningSentence(memory, localeCode: localeCode);
      final chips = buildGraphSatelliteChips(
        memory,
        theme.colorScheme,
        localeCode: localeCode,
        onChipTap: (keyword, _) => openGraphKeywordFocus(ref, keyword),
      );
      final hasImage = imagePath != null && File(imagePath).existsSync();

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t['memory_focus_preview_title']!,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (hasImage || hasVideo)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    if (hasImage)
                      MemoryMediaHeroImage(
                        memoryId: memory.id,
                        photoIndex: 0,
                        path: imagePath!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 120,
                        color: memory.categoryColor.withValues(alpha: 0.2),
                        alignment: Alignment.center,
                        child: Icon(Icons.videocam_rounded, size: 40, color: memory.categoryColor),
                      ),
                    if (hasVideo)
                      const Positioned(
                        right: 10,
                        bottom: 10,
                        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                      ),
                    if (photoCount > 1)
                      Positioned(
                        right: 10,
                        top: 10,
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
                ),
              ),
            if (hasImage || hasVideo) const SizedBox(height: 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
            ],
            const SizedBox(height: 14),
            MemoryFocusMiniGraph(memory: memory, localeCode: localeCode),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                openGraphMemoryFocus(ref, memory);
              },
              icon: const Icon(Icons.hub_outlined),
              label: Text(t['memory_focus_open_graph']!),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t['close'] ?? '닫기'),
            ),
          ],
        ),
      );
    },
  );
}

/// 기억 1건 + 위성을 작은 정적 캔버스로 표시합니다.
class MemoryFocusMiniGraph extends StatelessWidget {
  const MemoryFocusMiniGraph({
    super.key,
    required this.memory,
    required this.localeCode,
  });

  final Memory memory;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final result = buildMemoryFocusGraphLayout(memory, localeCode: localeCode);
    final canvasSize = memoryFocusCanvasSize(result.layout.nodes.length);
    final positions = initialGraphPositions(result.layout.nodes, result.layout.edges, canvasSize);
    final nodeMap = {for (final n in result.layout.nodes) n.id: n};

    return AspectRatio(
      aspectRatio: 1.35,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: canvasSize,
                    painter: GraphEdgesPainter(
                      edges: result.layout.edges,
                      positions: positions,
                      nodeMap: nodeMap,
                      isDark: isDark,
                    ),
                  ),
                  ...result.layout.nodes.map((node) {
                    final pos = positions[node.id] ?? Offset(canvasSize.width / 2, canvasSize.height / 2);
                    final isHub = node.kind == GraphNodeKind.memory || node.kind == GraphNodeKind.group;
                    final w = isHub ? 160.0 : 96.0;
                    final h = isHub ? 52.0 : 34.0;
                    return Positioned(
                      left: pos.dx - w / 2,
                      top: pos.dy - h / 2,
                      child: Container(
                        width: w,
                        height: h,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: node.color.withValues(alpha: isHub ? 0.92 : 0.88),
                          borderRadius: BorderRadius.circular(isHub ? 14 : 10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          node.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isHub ? 11 : 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
