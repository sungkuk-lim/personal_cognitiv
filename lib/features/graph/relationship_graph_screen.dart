import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../features/memory/memory_detail_sheet.dart';
import '../../models/memory.dart';
import '../../providers/app_providers.dart';
import '../../providers/memory_notifier.dart';
import 'graph_layout.dart';

class RelationshipGraphScreen extends ConsumerStatefulWidget {
  const RelationshipGraphScreen({super.key});

  @override
  ConsumerState<RelationshipGraphScreen> createState() => _RelationshipGraphScreenState();
}

class _RelationshipGraphScreenState extends ConsumerState<RelationshipGraphScreen> {
  final TransformationController _transformController = TransformationController();
  bool _draggingNode = false;
  Map<String, Offset>? _livePositions;
  int? _activePointer;
  String? _dragNodeId;
  Set<String> _dragGroup = {};
  bool _moveCluster = false;
  Offset? _lastCanvasPosition;
  bool _moved = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  String? _nodeAt(Offset canvasPos, List<GraphNodeData> nodes, Map<String, Offset> positions) {
    final sorted = [...nodes]
      ..sort((a, b) {
        if (a.isMemory == b.isMemory) return 0;
        return a.isMemory ? -1 : 1;
      });
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

  void _beginDrag(Map<String, Offset> positions) {
    _livePositions = Map<String, Offset>.from(positions);
  }

  void _applyDragDelta({
    required String primaryNodeId,
    required Offset delta,
  }) {
    if (delta == Offset.zero || _livePositions == null) return;
    if (_moveCluster) {
      for (final id in _dragGroup) {
        final base = _livePositions![id];
        if (base != null) _livePositions![id] = base + delta;
      }
    } else {
      final base = _livePositions![primaryNodeId];
      if (base != null) _livePositions![primaryNodeId] = base + delta;
    }
  }

  void _finishDrag(WidgetRef ref) {
    final live = _livePositions;
    if (live != null && _moved) {
      ref.read(graphNodePositionsProvider.notifier).state = {
        ...ref.read(graphNodePositionsProvider),
        ...live,
      };
      saveGraphPositions(ref.read(preferencesProvider), ref.read(graphNodePositionsProvider));
    }
    _livePositions = null;
  }

  void _resetPointerState() {
    _activePointer = null;
    _dragNodeId = null;
    _dragGroup = {};
    _moveCluster = false;
    _lastCanvasPosition = null;
    _moved = false;
    _draggingNode = false;
  }

  void _handlePointerDown(
    PointerDownEvent event,
    List<GraphNodeData> nodes,
    Map<String, Offset> positions,
    Map<String, Set<String>> clusterByNode,
    Map<String, GraphNodeData> nodeMap,
  ) {
    _activePointer = event.pointer;
    _lastCanvasPosition = _transformController.toScene(event.localPosition);
    _moved = false;
    final nodeId = _nodeAt(_lastCanvasPosition!, nodes, positions);
    if (nodeId == null) return;

    final node = nodeMap[nodeId]!;
    _dragNodeId = nodeId;
    _dragGroup = clusterByNode[nodeId] ?? {nodeId};
    _moveCluster = node.isMemory;
    _beginDrag(positions);
    setState(() => _draggingNode = true);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer || _dragNodeId == null || _livePositions == null) return;
    final canvasPos = _transformController.toScene(event.localPosition);
    final last = _lastCanvasPosition;
    if (last == null) return;
    final delta = canvasPos - last;
    _lastCanvasPosition = canvasPos;
    if (delta == Offset.zero) return;
    _moved = true;
    setState(() {
      _applyDragDelta(primaryNodeId: _dragNodeId!, delta: delta);
    });
  }

  void _handlePointerEnd(PointerEvent event, WidgetRef ref, List<Memory> memories, Map<String, String> imagePaths) {
    if (_activePointer != event.pointer) return;
    if (_dragNodeId != null && !_moved) {
      ref.read(selectedGraphNodeProvider.notifier).state = _dragNodeId;
      final nodeId = _dragNodeId!;
      if (nodeId.startsWith('memory_')) {
        final memoryId = nodeId.replaceFirst('memory_', '');
        final matches = memories.where((m) => m.id == memoryId);
        if (matches.isNotEmpty && mounted) {
          showMemoryDetailSheet(context, matches.first, imagePath: imagePaths[memoryId]);
        }
      }
    }
    if (_dragNodeId != null) _finishDrag(ref);
    setState(_resetPointerState);
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryListProvider);
    final imagePaths = ref.watch(memoryImagePathsProvider);
    final highlightedEntities = ref.watch(highlightedEntitiesProvider);
    final selectedNodeId = ref.watch(selectedGraphNodeProvider);
    final storedPositions = ref.watch(graphNodePositionsProvider);
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (memories.isEmpty) {
      return Center(child: Text(t['no_graph']!));
    }

    final layout = buildMemoryGraphLayout(memories);
    final nodeMap = {for (final node in layout.nodes) node.id: node};
    final clusters = buildGraphClusters(layout.nodes, layout.edges);
    final clusterByNode = <String, Set<String>>{
      for (final cluster in clusters)
        for (final nodeId in cluster) nodeId: cluster,
    };
    final canvasSize = graphCanvasSize(clusters.length);
    final basePositions = <String, Offset>{};
    final defaults = initialGraphPositions(layout.nodes, layout.edges, canvasSize);
    for (final node in layout.nodes) {
      basePositions[node.id] = storedPositions[node.id] ?? defaults[node.id] ?? Offset(canvasSize.width / 2, canvasSize.height / 2);
    }
    final positions = _livePositions ?? basePositions;

    final sortedNodes = [...layout.nodes]
      ..sort((a, b) {
        if (a.isMemory == b.isMemory) return 0;
        return a.isMemory ? -1 : 1;
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(t['graph_hint']!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _handlePointerDown(event, layout.nodes, positions, clusterByNode, nodeMap),
            onPointerMove: _handlePointerMove,
            onPointerUp: (event) => _handlePointerEnd(event, ref, memories, imagePaths),
            onPointerCancel: (event) => _handlePointerEnd(event, ref, memories, imagePaths),
            child: InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(1000),
              minScale: 0.01,
              maxScale: 5.0,
              panEnabled: !_draggingNode,
              scaleEnabled: !_draggingNode,
              child: SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: canvasSize,
                      painter: GraphEdgesPainter(
                        edges: layout.edges,
                        positions: positions,
                        nodeMap: nodeMap,
                        isDark: isDark,
                      ),
                    ),
                    ...sortedNodes.map((node) {
                      final position = positions[node.id]!;
                      final entityName = node.isMemory ? null : node.title;
                      final isHighlighted = node.isMemory
                          ? node.subtitle.split(' · ').any(highlightedEntities.contains)
                          : highlightedEntities.contains(entityName);
                      final isSelected = selectedNodeId == node.id;
                      final isDragging = _draggingNode && _dragGroup.contains(node.id);

                      return Positioned(
                        key: ValueKey(node.id),
                        left: position.dx - node.size.width / 2,
                        top: position.dy - node.size.height / 2,
                        child: _GraphNodeCard(
                          node: node,
                          isHighlighted: isHighlighted,
                          isSelected: isSelected,
                          isDragging: isDragging,
                          isDark: isDark,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphNodeCard extends StatelessWidget {
  final GraphNodeData node;
  final bool isHighlighted;
  final bool isSelected;
  final bool isDragging;
  final bool isDark;

  const _GraphNodeCard({
    required this.node,
    required this.isHighlighted,
    required this.isSelected,
    required this.isDragging,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isHighlighted ? Colors.amber : node.color;
    final borderColor = isSelected || isDragging ? Colors.white : accent.withValues(alpha: 0.85);

    return IgnorePointer(
      child: AnimatedContainer(
        duration: isDragging ? Duration.zero : const Duration(milliseconds: 180),
        width: node.size.width,
        height: node.size.height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(node.isMemory ? 22 : 18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: node.isMemory
                ? [accent.withValues(alpha: isDark ? 0.55 : 0.82), accent.withValues(alpha: isDark ? 0.28 : 0.55)]
                : [Colors.white.withValues(alpha: isDark ? 0.14 : 0.92), accent.withValues(alpha: isDark ? 0.22 : 0.18)],
          ),
          border: Border.all(color: borderColor, width: isSelected || isDragging ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: isDark ? 0.35 : 0.25), blurRadius: isHighlighted || isDragging ? 22 : 14, spreadRadius: isHighlighted || isDragging ? 1 : 0, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              node.title,
              maxLines: node.isMemory ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: node.isMemory ? 13 : 11,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: node.isMemory || isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (node.isMemory && node.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                node.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.82)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
