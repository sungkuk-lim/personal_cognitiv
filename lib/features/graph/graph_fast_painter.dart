import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'graph_layout.dart';

/// 드래그/팬 중 전용 경량 페인터.
/// 위젯 트리(이미지·아바타·그라데이션) 재빌드 없이 캔버스만 갱신합니다.
class GraphFastPainter extends CustomPainter {
  GraphFastPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.isDark,
    required this.tick,
    this.dragGroup = const {},
    this.drawLabels = true,
  });

  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final bool isDark;
  final int tick;
  final Set<String> dragGroup;
  final bool drawLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.28);
    final relationPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.7);
    final memLinkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.deepPurpleAccent.withValues(alpha: 0.55);

    for (final edge in edges) {
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;
      final paint = edge.relationEdge
          ? relationPaint
          : (edge.memoryToMemory || edge.semanticLink)
              ? memLinkPaint
              : edgePaint;
      canvas.drawLine(from, to, paint);
    }

    for (final node in nodes) {
      final center = positions[node.id];
      if (center == null) continue;
      final rect = Rect.fromCenter(
        center: center,
        width: node.size.width,
        height: node.size.height,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(node.isMemory ? 22 : 18),
      );
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.alphaBlend(
          node.color.withValues(alpha: isDark ? 0.55 : 0.72),
          isDark ? const Color(0xFF1A1A1A) : Colors.white,
        );
      canvas.drawRRect(rrect, fill);

      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dragGroup.contains(node.id) ? 2.2 : 1.0
        ..color = dragGroup.contains(node.id)
            ? Colors.white
            : node.color.withValues(alpha: 0.9);
      canvas.drawRRect(rrect, border);

      if (!drawLabels) continue;
      final title = node.title.trim();
      if (title.isEmpty) continue;
      final label = title.length > 10 ? '${title.substring(0, 10)}…' : title;
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontSize: node.isMemory ? 12 : 11,
          fontWeight: FontWeight.w700,
          maxLines: 1,
          ellipsis: '…',
        ),
      )
        ..pushStyle(ui.TextStyle(color: Colors.white))
        ..addText(label);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: node.size.width - 10));
      canvas.drawParagraph(
        paragraph,
        Offset(
          center.dx - paragraph.maxIntrinsicWidth / 2,
          center.dy - paragraph.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GraphFastPainter oldDelegate) {
    // positions 맵은 제자리 갱신되므로 tick으로 리페인트 판단
    return oldDelegate.tick != tick ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.isDark != isDark ||
        oldDelegate.drawLabels != drawLabels ||
        oldDelegate.dragGroup != dragGroup;
  }
}
