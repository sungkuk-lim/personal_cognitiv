from pathlib import Path

p = Path("lib/features/graph/graph_layout.dart")
t = p.read_text(encoding="utf-8")

# Fix pet subtitle label 반려 -> 반려견 in _kindLabel and attach paths
t = t.replace("GraphNodeKind.pet => '반려',", "GraphNodeKind.pet => '반려견',")

# GraphEdgesPainter: add optional visibleNodeIds
old = """class GraphEdgesPainter extends CustomPainter {
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
      if (!edge.bridgeLink) continue;
      _paintBridgeEdge(canvas, edge);
    }

    for (final edge in edges) {
      if (edge.bridgeLink) continue;
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;
"""

new = """class GraphEdgesPainter extends CustomPainter {
  final List<GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final Map<String, GraphNodeData> nodeMap;
  final bool isDark;
  final Set<String>? visibleNodeIds;

  GraphEdgesPainter({
    required this.edges,
    required this.positions,
    required this.nodeMap,
    required this.isDark,
    this.visibleNodeIds,
  });

  bool _edgeVisible(GraphEdgeData edge) {
    final ids = visibleNodeIds;
    if (ids == null || ids.isEmpty) return true;
    return ids.contains(edge.fromId) && ids.contains(edge.toId);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      if (!edge.bridgeLink) continue;
      if (!_edgeVisible(edge)) continue;
      _paintBridgeEdge(canvas, edge);
    }

    for (final edge in edges) {
      if (edge.bridgeLink) continue;
      if (!_edgeVisible(edge)) continue;
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;
"""

if old not in t:
    raise SystemExit("painter block not found")
t = t.replace(old, new)

# shouldRepaint include visibleNodeIds
if "visibleNodeIds" not in t[t.find("shouldRepaint"): t.find("shouldRepaint") + 400]:
    t = t.replace(
        "    return oldDelegate.edges != edges ||\n"
        "        oldDelegate.positions != positions ||\n"
        "        oldDelegate.isDark != isDark;",
        "    return oldDelegate.edges != edges ||\n"
        "        oldDelegate.positions != positions ||\n"
        "        oldDelegate.isDark != isDark ||\n"
        "        oldDelegate.visibleNodeIds != visibleNodeIds;",
    )

p.write_text(t, encoding="utf-8", newline="\n")
print("patched painter + pet label")
