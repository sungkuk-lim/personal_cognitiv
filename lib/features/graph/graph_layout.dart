import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/memory.dart';
import '../../utils/ocr_utils.dart';

class GraphNodeData {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final bool isMemory;
  final Size size;

  const GraphNodeData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isMemory,
    required this.size,
  });
}

class GraphEdgeData {
  final String fromId;
  final String toId;
  final Color color;

  const GraphEdgeData({required this.fromId, required this.toId, required this.color});
}

class GraphLayout {
  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;

  const GraphLayout({required this.nodes, required this.edges});
}

GraphLayout buildMemoryGraphLayout(List<Memory> memories) {
  final nodes = <GraphNodeData>[];
  final edges = <GraphEdgeData>[];
  final entityIds = <String, String>{};

  for (final memory in memories) {
    final memoryId = 'memory_${memory.id}';
    final keywords = graphKeywordsForMemory(memory);
    nodes.add(GraphNodeData(
      id: memoryId,
      title: graphTitleForMemory(memory),
      subtitle: keywords.take(3).join(' · '),
      color: memory.categoryColor,
      isMemory: true,
      size: const Size(168, 92),
    ));

    for (final entity in keywords) {
      final entityId = entityIds.putIfAbsent(entity, () => 'entity_$entity');
      if (!nodes.any((node) => node.id == entityId)) {
        nodes.add(GraphNodeData(
          id: entityId,
          title: entity,
          subtitle: '',
          color: memory.categoryColor,
          isMemory: false,
          size: const Size(132, 60),
        ));
      }
      edges.add(GraphEdgeData(fromId: memoryId, toId: entityId, color: memory.categoryColor));
    }
  }

  return GraphLayout(nodes: nodes, edges: edges);
}

List<Set<String>> buildGraphClusters(List<GraphNodeData> nodes, List<GraphEdgeData> edges) {
  final adjacency = <String, Set<String>>{for (final node in nodes) node.id: {}};
  for (final edge in edges) {
    adjacency[edge.fromId]!.add(edge.toId);
    adjacency[edge.toId]!.add(edge.fromId);
  }

  final visited = <String>{};
  final clusters = <Set<String>>[];
  for (final node in nodes) {
    if (visited.contains(node.id)) continue;
    final cluster = <String>{};
    final queue = <String>[node.id];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!visited.add(id)) continue;
      cluster.add(id);
      queue.addAll(adjacency[id] ?? const {});
    }
    clusters.add(cluster);
  }
  return clusters;
}

Size graphCanvasSize(int clusterCount) {
  if (clusterCount <= 1) return const Size(1200, 900);
  final cols = math.max(1, math.sqrt(clusterCount).ceil());
  final rows = (clusterCount / cols).ceil();
  return Size(
    math.max(1200, cols * 380.0 + 440.0),
    math.max(900, rows * 320.0 + 440.0),
  );
}

Map<String, Offset> initialGraphPositions(
  List<GraphNodeData> nodes,
  List<GraphEdgeData> edges,
  Size canvasSize,
) {
  final nodeMap = {for (final node in nodes) node.id: node};
  final clusters = buildGraphClusters(nodes, edges);
  final positions = <String, Offset>{};
  if (clusters.isEmpty) return positions;

  final cols = math.max(1, math.sqrt(clusters.length).ceil());
  const clusterSpacingX = 380.0;
  const clusterSpacingY = 320.0;

  for (var clusterIndex = 0; clusterIndex < clusters.length; clusterIndex++) {
    final col = clusterIndex % cols;
    final row = clusterIndex ~/ cols;
    final clusterCenter = Offset(220 + col * clusterSpacingX, 220 + row * clusterSpacingY);
    final componentNodes = clusters[clusterIndex].map((id) => nodeMap[id]!).toList();
    final memories = componentNodes.where((node) => node.isMemory).toList();
    final keywords = componentNodes.where((node) => !node.isMemory).toList();

    if (memories.isEmpty) {
      for (var i = 0; i < keywords.length; i++) {
        final angle = (2 * math.pi * i / math.max(keywords.length, 1)) - math.pi / 2;
        positions[keywords[i].id] = clusterCenter + Offset(math.cos(angle) * 40, math.sin(angle) * 40);
      }
      continue;
    }

    for (var i = 0; i < memories.length; i++) {
      final angle = (2 * math.pi * i / memories.length) - math.pi / 2;
      positions[memories[i].id] = clusterCenter + Offset(math.cos(angle) * 72, math.sin(angle) * 56);
    }

    for (var i = 0; i < keywords.length; i++) {
      final angle = (2 * math.pi * i / math.max(keywords.length, 1));
      positions[keywords[i].id] = clusterCenter + Offset(math.cos(angle) * 148, math.sin(angle) * 118);
    }
  }

  return positions;
}

class GraphEdgesPainter extends CustomPainter {
  final List<GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final Map<String, GraphNodeData> nodeMap;
  final bool isDark;

  GraphEdgesPainter({
    required this.edges,
    required this.positions,
    required this.nodeMap,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      final fromNode = nodeMap[edge.fromId];
      final toNode = nodeMap[edge.toId];
      if (from == null || to == null || fromNode == null || toNode == null) continue;

      final start = from;
      final end = to;
      final control = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 - 36);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = edge.color.withValues(alpha: isDark ? 0.18 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          colors: [edge.color.withValues(alpha: 0.15), edge.color.withValues(alpha: 0.75), edge.color.withValues(alpha: 0.15)],
        ).createShader(Rect.fromPoints(start, end));
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphEdgesPainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.edges != edges || oldDelegate.isDark != isDark;
  }
}
