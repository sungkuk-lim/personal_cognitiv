import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/memory.dart';
import '../../utils/semantic_search.dart';
import 'graph_fast_painter.dart';
import 'graph_layout.dart';
import 'graph_node_context.dart';

/// 관계망 드래그 전용 호스트.
/// 부모 setState 없이 ValueNotifier만으로 드래그 프레임을 갱신합니다.
class GraphInteractiveCanvas extends StatefulWidget {
  const GraphInteractiveCanvas({
    super.key,
    required this.canvasSize,
    required this.nodes,
    required this.edges,
    required this.basePositions,
    required this.nodeMap,
    required this.isDark,
    required this.transformationController,
    required this.memoryById,
    required this.nodeMediaIndex,
    required this.isFocusMode,
    required this.isMemoryFocusMode,
    required this.highlightedEntities,
    required this.graphSearchQuery,
    required this.selectedNodeId,
    required this.mergedExpansions,
    required this.localeCode,
    required this.buildNodeCard,
    required this.onTapNode,
    required this.onDragEnd,
    this.cullNodes = false,
  });

  final Size canvasSize;
  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final Map<String, Offset> basePositions;
  final Map<String, GraphNodeData> nodeMap;
  final bool isDark;
  final TransformationController transformationController;
  final Map<String, Memory> memoryById;
  final Map<String, GraphNodeMediaInfo> nodeMediaIndex;
  final bool isFocusMode;
  final bool isMemoryFocusMode;
  final List<String> highlightedEntities;
  final String graphSearchQuery;
  final String? selectedNodeId;
  final Map<String, GraphSatelliteExpandMode> mergedExpansions;
  final String localeCode;
  final bool cullNodes;
  final Widget Function({
    required GraphNodeData node,
    required bool isHighlighted,
    required bool isSelected,
    required bool isDragging,
    required String? thumbnailPath,
    required int photoCount,
    required bool showVideoBadge,
    required bool satellitesExpanded,
  }) buildNodeCard;
  final void Function(String nodeId, Offset canvasPos) onTapNode;
  final void Function(Map<String, Offset> positions) onDragEnd;

  @override
  State<GraphInteractiveCanvas> createState() => _GraphInteractiveCanvasState();
}

class _GraphInteractiveCanvasState extends State<GraphInteractiveCanvas> {
  final ValueNotifier<bool> _dragging = ValueNotifier(false);
  final ValueNotifier<int> _tick = ValueNotifier(0);
  Map<String, Offset>? _live;
  int? _pointer;
  String? _dragId;
  Set<String> _group = {};
  bool _moveCluster = false;
  Offset? _lastPos;
  bool _moved = false;
  Timer? _longPress;
  Map<String, Set<String>> _groupCache = {};

  @override
  void initState() {
    super.initState();
    _rebuildGroupCache();
  }

  @override
  void didUpdateWidget(covariant GraphInteractiveCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.nodes, widget.nodes) ||
        !identical(oldWidget.edges, widget.edges)) {
      _rebuildGroupCache();
    }
  }

  void _rebuildGroupCache() {
    final cache = <String, Set<String>>{};
    for (final node in widget.nodes) {
      if (isGraphHubLikeNode(node)) {
        cache[node.id] = dragGroupForNode(node.id, widget.edges, widget.nodes);
      }
    }
    _groupCache = cache;
  }

  @override
  void dispose() {
    _longPress?.cancel();
    _dragging.dispose();
    _tick.dispose();
    super.dispose();
  }

  String? _nodeAt(Offset canvasPos) {
    final sorted = [...widget.nodes]
      ..sort((a, b) {
        if (a.isMemory == b.isMemory) return 0;
        return a.isMemory ? -1 : 1;
      });
    final positions = _live ?? widget.basePositions;
    for (final node in sorted.reversed) {
      final center = positions[node.id];
      if (center == null) continue;
      final slop = node.isMemory ? 14.0 : 18.0;
      final rect = Rect.fromCenter(
        center: center,
        width: node.size.width + slop * 2,
        height: node.size.height + slop * 2,
      );
      if (rect.contains(canvasPos)) return node.id;
    }
    return null;
  }

  void _onDown(PointerDownEvent e) {
    _pointer = e.pointer;
    _lastPos = widget.transformationController.toScene(e.localPosition);
    _moved = false;
    _moveCluster = false;
    final id = _nodeAt(_lastPos!);
    if (id == null) {
      _dragId = null;
      return;
    }
    _dragId = id;
    _group = _groupCache[id] ?? dragGroupForNode(id, widget.edges, widget.nodes);
    _live = Map<String, Offset>.from(widget.basePositions);
    final node = widget.nodeMap[id];
    _longPress?.cancel();
    if (node != null && isGraphHubLikeNode(node)) {
      _longPress = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || _dragId != id || _moved) return;
        _moveCluster = true;
        HapticFeedback.mediumImpact();
        _tick.value++;
      });
    }
    // 부모 setState 없이 드래그 모드 진입
    _dragging.value = true;
    _tick.value++;
  }

  void _onMove(PointerMoveEvent e) {
    if (_pointer != e.pointer || _dragId == null || _live == null) return;
    final pos = widget.transformationController.toScene(e.localPosition);
    final last = _lastPos;
    if (last == null) return;
    final delta = pos - last;
    _lastPos = pos;
    if (delta == Offset.zero) return;
    if (!_moved && delta.distance > 2.0) {
      _moved = true;
      if (!_moveCluster) {
        _longPress?.cancel();
        _longPress = null;
      }
    }
    if (!_moved) return;

    if (_moveCluster) {
      for (final id in _group) {
        final base = _live![id];
        if (base != null) _live![id] = base + delta;
      }
    } else {
      final base = _live![_dragId!];
      if (base != null) _live![_dragId!] = base + delta;
    }
    _tick.value++;
  }

  void _onUp(PointerEvent e) {
    if (_pointer != e.pointer) return;
    _longPress?.cancel();
    _longPress = null;
    final id = _dragId;
    final moved = _moved;
    final live = _live;
    final canvasPos = _lastPos;

    if (id != null && !moved && canvasPos != null) {
      widget.onTapNode(id, canvasPos);
    } else if (id != null && moved && live != null) {
      widget.onDragEnd(live);
    }

    _pointer = null;
    _dragId = null;
    _group = {};
    _moveCluster = false;
    _lastPos = null;
    _moved = false;
    _live = null;
    _dragging.value = false;
    _tick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: ValueListenableBuilder<bool>(
        valueListenable: _dragging,
        builder: (context, dragging, _) {
          return InteractiveViewer(
            transformationController: widget.transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.02,
            maxScale: 5.0,
            panEnabled: !dragging,
            scaleEnabled: !dragging,
            child: SizedBox(
              width: widget.canvasSize.width,
              height: widget.canvasSize.height,
              child: dragging
                  ? ValueListenableBuilder<int>(
                      valueListenable: _tick,
                      builder: (context, tick, _) {
                        return CustomPaint(
                          size: widget.canvasSize,
                          isComplex: true,
                          willChange: true,
                          painter: GraphFastPainter(
                            nodes: widget.nodes,
                            edges: widget.edges,
                            positions: _live ?? widget.basePositions,
                            isDark: widget.isDark,
                            tick: tick,
                            drawLabels: false,
                            dragGroup: _moveCluster
                                ? _group
                                : {if (_dragId != null) _dragId!},
                          ),
                        );
                      },
                    )
                  : _IdleNodesLayer(
                      canvasSize: widget.canvasSize,
                      nodes: widget.nodes,
                      positions: widget.basePositions,
                      edges: widget.edges,
                      nodeMap: widget.nodeMap,
                      isDark: widget.isDark,
                      memoryById: widget.memoryById,
                      nodeMediaIndex: widget.nodeMediaIndex,
                      isFocusMode: widget.isFocusMode,
                      isMemoryFocusMode: widget.isMemoryFocusMode,
                      highlightedEntities: widget.highlightedEntities,
                      graphSearchQuery: widget.graphSearchQuery,
                      selectedNodeId: widget.selectedNodeId,
                      mergedExpansions: widget.mergedExpansions,
                      buildNodeCard: widget.buildNodeCard,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _IdleNodesLayer extends StatelessWidget {
  const _IdleNodesLayer({
    required this.canvasSize,
    required this.nodes,
    required this.positions,
    required this.edges,
    required this.nodeMap,
    required this.isDark,
    required this.memoryById,
    required this.nodeMediaIndex,
    required this.isFocusMode,
    required this.isMemoryFocusMode,
    required this.highlightedEntities,
    required this.graphSearchQuery,
    required this.selectedNodeId,
    required this.mergedExpansions,
    required this.buildNodeCard,
  });

  final Size canvasSize;
  final List<GraphNodeData> nodes;
  final Map<String, Offset> positions;
  final List<GraphEdgeData> edges;
  final Map<String, GraphNodeData> nodeMap;
  final bool isDark;
  final Map<String, Memory> memoryById;
  final Map<String, GraphNodeMediaInfo> nodeMediaIndex;
  final bool isFocusMode;
  final bool isMemoryFocusMode;
  final List<String> highlightedEntities;
  final String graphSearchQuery;
  final String? selectedNodeId;
  final Map<String, GraphSatelliteExpandMode> mergedExpansions;
  final Widget Function({
    required GraphNodeData node,
    required bool isHighlighted,
    required bool isSelected,
    required bool isDragging,
    required String? thumbnailPath,
    required int photoCount,
    required bool showVideoBadge,
    required bool satellitesExpanded,
  }) buildNodeCard;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: canvasSize,
            painter: GraphEdgesPainter(
              edges: edges,
              positions: positions,
              nodeMap: nodeMap,
              isDark: isDark,
              declutter: nodes.length > 28,
              hideLabels: nodes.length > 40,
            ),
          ),
          ...nodes.map((node) {
            final position = positions[node.id];
            if (position == null) return const SizedBox.shrink();
            final entityName = node.isMemory ? null : node.title;
            final linkedMemory = node.id.startsWith('memory_')
                ? memoryById[node.id.replaceFirst('memory_', '')]
                : null;
            final isHighlighted = isFocusMode
                ? (isMemoryFocusMode ||
                    node.id.startsWith('focus_hub_') ||
                    node.isMemory)
                : node.isMemory
                    ? linkedMemory != null &&
                        memoryMatchesAnyEntity(linkedMemory, highlightedEntities)
                    : highlightedEntities.contains(entityName) ||
                        highlightedEntities.contains(node.title);
            final q = graphSearchQuery;
            final matches = q.isEmpty ||
                node.title.toLowerCase().contains(q) ||
                node.placeLabel.toLowerCase().contains(q) ||
                node.subtitle.toLowerCase().contains(q);
            final isDimmed = q.isNotEmpty && !matches;
            final media = nodeMediaIndex[node.id] ?? GraphNodeMediaInfo.empty;
            final memoryId =
                node.id.startsWith('memory_') ? node.id.replaceFirst('memory_', '') : null;
            final satellitesExpanded =
                memoryId != null && mergedExpansions.containsKey(memoryId);

            return Positioned(
              key: ValueKey(node.id),
              left: position.dx - node.size.width / 2,
              top: position.dy - node.size.height / 2,
              child: Opacity(
                opacity: isDimmed ? 0.28 : 1,
                child: buildNodeCard(
                  node: node,
                  isHighlighted: isHighlighted || (q.isNotEmpty && matches),
                  isSelected: selectedNodeId == node.id,
                  isDragging: false,
                  thumbnailPath: media.thumbnailPath,
                  photoCount: media.photoCount,
                  showVideoBadge: media.hasVideo,
                  satellitesExpanded: satellitesExpanded,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
