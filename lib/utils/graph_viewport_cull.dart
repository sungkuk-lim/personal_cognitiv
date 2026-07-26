import 'package:flutter/material.dart';

import '../features/graph/graph_layout.dart';

/// InteractiveViewer 변환 행렬 기준으로 씬 좌표계의 가시 영역을 계산합니다.
Rect graphVisibleSceneRect({
  required Matrix4 transform,
  required Size viewportSize,
  double margin = 160,
}) {
  if (viewportSize.isEmpty) {
    return const Rect.fromLTWH(0, 0, 10000, 10000);
  }
  final inverse = Matrix4.inverted(transform);
  final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
  final bottomRight = MatrixUtils.transformPoint(
    inverse,
    Offset(viewportSize.width, viewportSize.height),
  );
  return Rect.fromPoints(topLeft, bottomRight).inflate(margin);
}

bool graphNodeIntersectsRect({
  required GraphNodeData node,
  required Offset center,
  required Rect sceneRect,
  double slop = 24,
}) {
  final rect = Rect.fromCenter(
    center: center,
    width: node.size.width + slop * 2,
    height: node.size.height + slop * 2,
  );
  return sceneRect.overlaps(rect);
}

/// 가시 영역과 겹치는 노드 ID 집합.
Set<String> visibleGraphNodeIds({
  required Iterable<GraphNodeData> nodes,
  required Map<String, Offset> positions,
  required Matrix4 transform,
  required Size viewportSize,
  double margin = 160,
}) {
  final sceneRect = graphVisibleSceneRect(
    transform: transform,
    viewportSize: viewportSize,
    margin: margin,
  );
  final visible = <String>{};
  for (final node in nodes) {
    final center = positions[node.id];
    if (center == null) continue;
    if (graphNodeIntersectsRect(node: node, center: center, sceneRect: sceneRect)) {
      visible.add(node.id);
    }
  }
  return visible;
}
