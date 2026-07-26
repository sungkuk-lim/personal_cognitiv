import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/graph/graph_layout.dart';

/// 모든 노드가 들어가는 콘텐츠 경계(패딩 포함).
Rect graphContentBounds(
  List<GraphNodeData> nodes,
  Map<String, Offset> positions, {
  double padding = 140,
}) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;

  for (final node in nodes) {
    final p = positions[node.id];
    if (p == null) continue;
    final hw = node.size.width / 2;
    final hh = node.size.height / 2;
    minX = math.min(minX, p.dx - hw);
    minY = math.min(minY, p.dy - hh);
    maxX = math.max(maxX, p.dx + hw);
    maxY = math.max(maxY, p.dy + hh);
  }

  if (minX == double.infinity) {
    return Rect.fromLTWH(0, 0, 1000, 800);
  }
  return Rect.fromLTRB(minX - padding, minY - padding, maxX + padding, maxY + padding);
}

/// 콘텐츠 경계에 맞춰 캔버스 크기를 키웁니다 (고정 크기 한계 완화).
Size expandCanvasForContent(Size baseSize, Rect contentBounds) {
  return Size(
    math.max(baseSize.width, contentBounds.width),
    math.max(baseSize.height, contentBounds.height),
  );
}

/// 노드가 캔버스 밖으로 나가지 않도록 위치를 이동합니다.
Map<String, Offset> shiftPositionsIntoCanvas(
  Map<String, Offset> positions,
  Rect contentBounds,
  Size canvasSize, {
  double margin = 80,
}) {
  final shiftX = contentBounds.left < margin ? margin - contentBounds.left : 0.0;
  final shiftY = contentBounds.top < margin ? margin - contentBounds.top : 0.0;
  if (shiftX == 0 && shiftY == 0) return positions;
  final delta = Offset(shiftX, shiftY);
  return {for (final e in positions.entries) e.key: e.value + delta};
}

/// 전체 그래프가 뷰포트에 들어오도록 변환 행렬을 설정합니다.
void fitGraphToViewport({
  required TransformationController controller,
  required Rect contentBounds,
  required Size viewportSize,
  double maxScale = 5.0,
}) {
  if (viewportSize.width <= 1 || viewportSize.height <= 1) return;
  final cw = contentBounds.width;
  final ch = contentBounds.height;
  if (cw <= 1 || ch <= 1) return;

  final scale = math.min(viewportSize.width / cw, viewportSize.height / ch).clamp(0.02, maxScale);
  final tx = (viewportSize.width - cw * scale) / 2 - contentBounds.left * scale;
  final ty = (viewportSize.height - ch * scale) / 2 - contentBounds.top * scale;
  controller.value = Matrix4.identity()
    ..translate(tx, ty)
    ..scale(scale);
}
