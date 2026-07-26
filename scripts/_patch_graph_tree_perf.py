# -*- coding: utf-8 -*-
"""Patch graph_layout.dart: tree positions, drag subtree, edge declutter."""
from pathlib import Path

path = Path("lib/features/graph/graph_layout.dart")
text = path.read_text(encoding="utf-8")

old_drag = '''/// 드래그 시 함께 움직일 노드 (기억/허브 + 직접 연결 위성만).
Set<String> dragGroupForNode(String nodeId, List<GraphEdgeData> edges, List<GraphNodeData> nodes) {
  final nodeMap = {for (final n in nodes) n.id: n};
  final node = nodeMap[nodeId];
  if (node == null) return {nodeId};

  if (nodeId.startsWith('focus_hub_')) {
    final attached = <String>{nodeId};
    for (final edge in edges) {
      if (edge.fromId == nodeId) attached.add(edge.toId);
    }
    return attached;
  }

  if (node.kind == GraphNodeKind.group) {
    final groupId = nodeId;
    final attached = <String>{groupId};
    for (final edge in edges) {
      if (edge.memoryToMemory) continue;
      if (edge.fromId == groupId) attached.add(edge.toId);
      if (edge.toId == groupId) attached.add(edge.fromId);
    }
    for (final edge in edges) {
      if (!edge.memoryToMemory) continue;
      if (attached.contains(edge.fromId)) attached.add(edge.toId);
      if (attached.contains(edge.toId)) attached.add(edge.fromId);
    }
    return attached;
  }

  if (node.kind == GraphNodeKind.memory) {
    final attached = <String>{nodeId};
    for (final edge in edges) {
      if (edge.memoryToMemory) continue;
      if (edge.fromId == nodeId) attached.add(edge.toId);
    }
    return attached;
  }

  return {nodeId};
}'''

new_drag = '''/// 드래그 시 함께 움직일 노드 (허브 + 하위 트리 위성).
Set<String> dragGroupForNode(String nodeId, List<GraphEdgeData> edges, List<GraphNodeData> nodes) {
  final nodeMap = {for (final n in nodes) n.id: n};
  final node = nodeMap[nodeId];
  if (node == null) return {nodeId};

  final isHubLike = node.kind == GraphNodeKind.group ||
      node.kind == GraphNodeKind.memory ||
      node.kind == GraphNodeKind.eventHub ||
      nodeId.startsWith('focus_hub_') ||
      nodeId.startsWith('event_hub_') ||
      nodeId.startsWith('person_hub_') ||
      nodeId.startsWith('group_');

  if (!isHubLike) return {nodeId};

  final children = <String, List<String>>{};
  for (final edge in edges) {
    // 의미 교차 링크는 그룹 드래그에 넣지 않아 엉킴을 줄입니다.
    if (edge.semanticLink) continue;
    if (edge.memoryToMemory && node.kind != GraphNodeKind.group) continue;
    children.putIfAbsent(edge.fromId, () => []).add(edge.toId);
    if (node.kind == GraphNodeKind.group && edge.memoryToMemory) {
      children.putIfAbsent(edge.toId, () => []).add(edge.fromId);
    }
  }

  final attached = <String>{};
  final queue = <String>[nodeId];
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    if (!attached.add(id)) continue;
    for (final child in children[id] ?? const <String>[]) {
      if (nodeMap.containsKey(child)) queue.add(child);
    }
  }
  return attached;
}

bool isGraphHubLikeNode(GraphNodeData node) {
  return node.kind == GraphNodeKind.group ||
      node.kind == GraphNodeKind.memory ||
      node.kind == GraphNodeKind.eventHub ||
      node.id.startsWith('focus_hub_') ||
      node.id.startsWith('event_hub_') ||
      node.id.startsWith('person_hub_') ||
      node.id.startsWith('group_');
}'''

if old_drag not in text:
    raise SystemExit("dragGroupForNode block not found")
text = text.replace(old_drag, new_drag, 1)

old_init = '''Map<String, Offset> initialGraphPositions(
  List<GraphNodeData> nodes,
  List<GraphEdgeData> edges,
  Size canvasSize,
) {
  final positions = <String, Offset>{};
  if (nodes.isEmpty) return positions;

  final layoutClusters = <String, List<GraphNodeData>>{};
  for (final node in nodes) {
    layoutClusters.putIfAbsent(node.layoutClusterId, () => []).add(node);
  }

  final clusterKeys = layoutClusters.keys.toList();
  final cols = math.max(1, math.sqrt(clusterKeys.length).ceil());
  const spacingX = 460.0;
  const spacingY = 400.0;

  for (var i = 0; i < clusterKeys.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final center = Offset(280 + col * spacingX, 280 + row * spacingY);
    final members = layoutClusters[clusterKeys[i]]!;
    final hub = members.where((n) => n.kind == GraphNodeKind.group).toList();
    final memories = members.where((n) => n.kind == GraphNodeKind.memory).toList();
    final entityNotes = members.where((n) => n.id.startsWith('entity_note_')).toList();
    final satellites = members
        .where((n) => n.kind != GraphNodeKind.memory && n.kind != GraphNodeKind.group)
        .where((n) => !n.id.startsWith('entity_note_'))
        .toList();

    if (hub.isNotEmpty) {
      positions[hub.first.id] = center;
      for (var m = 0; m < memories.length; m++) {
        final angle = (2 * math.pi * m / math.max(memories.length, 1)) - math.pi / 2;
        positions[memories[m].id] = center + Offset(math.cos(angle) * 124, math.sin(angle) * 96);
      }
    } else if (memories.length == 1) {
      positions[memories.first.id] = center;
    } else if (memories.isNotEmpty) {
      for (var m = 0; m < memories.length; m++) {
        final angle = (2 * math.pi * m / memories.length) - math.pi / 2;
        positions[memories[m].id] = center + Offset(math.cos(angle) * 72, math.sin(angle) * 56);
      }
    }

    for (var s = 0; s < satellites.length; s++) {
      const slotsPerRing = 8;
      final ring = s ~/ slotsPerRing;
      final slot = s % slotsPerRing;
      final angle = (2 * math.pi * slot / slotsPerRing) + math.pi / 8 + ring * 0.18;
      final orbitX = 198.0 + ring * 56.0;
      final orbitY = 156.0 + ring * 44.0;
      final anchor = hub.isNotEmpty
          ? center
          : (memories.isNotEmpty ? positions[memories.first.id]! : center);
      positions[satellites[s].id] =
          anchor + Offset(math.cos(angle) * orbitX, math.sin(angle) * orbitY);
    }

    for (final noteNode in entityNotes) {
      String? parentId;
      for (final edge in edges) {
        if (edge.toId == noteNode.id) {
          parentId = edge.fromId;
          break;
        }
      }
      if (parentId == null) continue;
      final parentPos = positions[parentId];
      if (parentPos == null) continue;
      final siblings = entityNotes.where((n) {
        for (final edge in edges) {
          if (edge.toId == n.id && edge.fromId == parentId) return true;
        }
        return false;
      }).toList();
      final index = siblings.indexWhere((n) => n.id == noteNode.id).clamp(0, siblings.length - 1);
      positions[noteNode.id] = parentPos + Offset(-4, 52 + index * 48.0);
    }
  }

  for (final node in nodes) {
    positions.putIfAbsent(node.id, () => const Offset(240, 240));
  }
  return positions;
}'''

new_init = '''/// 저장된 허브 위치를 기준으로 기본 트리 오프셋을 재배치합니다.
/// 위성 펼침 시 원형 좌표로 엉키지 않게 허브 아래로 붙입니다.
Map<String, Offset> mergeStoredGraphPositions({
  required List<GraphNodeData> nodes,
  required List<GraphEdgeData> edges,
  required Map<String, Offset> defaults,
  required Map<String, Offset> stored,
  Offset fallback = const Offset(240, 240),
}) {
  final result = <String, Offset>{};
  final nodeMap = {for (final n in nodes) n.id: n};
  final parentOf = <String, String>{};
  for (final edge in edges) {
    if (edge.semanticLink || edge.memoryToMemory) continue;
    parentOf.putIfAbsent(edge.toId, () => edge.fromId);
  }

  // 허브·기억 등 앵커는 저장 좌표 우선
  for (final node in nodes) {
    final storedPos = stored[node.id];
    if (storedPos != null) {
      result[node.id] = storedPos;
      continue;
    }
    if (isGraphHubLikeNode(node) || node.kind == GraphNodeKind.memory) {
      result[node.id] = defaults[node.id] ?? fallback;
    }
  }

  // 위성은 부모 현재 위치 + (기본 위성 - 기본 부모) 상대 오프셋
  for (final node in nodes) {
    if (result.containsKey(node.id)) continue;
    final parentId = parentOf[node.id];
    final defNode = defaults[node.id];
    if (parentId != null) {
      final parentNow = result[parentId] ?? stored[parentId] ?? defaults[parentId];
      final parentDef = defaults[parentId];
      if (parentNow != null && parentDef != null && defNode != null) {
        result[node.id] = parentNow + (defNode - parentDef);
        continue;
      }
      if (parentNow != null) {
        result[node.id] = parentNow + const Offset(0, 110);
        continue;
      }
    }
    result[node.id] = defNode ?? fallback;
  }

  for (final node in nodes) {
    result.putIfAbsent(node.id, () => defaults[node.id] ?? fallback);
  }
  return result;
}

Map<String, Offset> initialGraphPositions(
  List<GraphNodeData> nodes,
  List<GraphEdgeData> edges,
  Size canvasSize,
) {
  final positions = <String, Offset>{};
  if (nodes.isEmpty) return positions;

  final layoutClusters = <String, List<GraphNodeData>>{};
  for (final node in nodes) {
    layoutClusters.putIfAbsent(node.layoutClusterId, () => []).add(node);
  }

  final children = <String, List<String>>{};
  final nodeMap = {for (final n in nodes) n.id: n};
  for (final edge in edges) {
    if (edge.semanticLink) continue;
    if (edge.memoryToMemory) continue;
    if (!nodeMap.containsKey(edge.fromId) || !nodeMap.containsKey(edge.toId)) continue;
    children.putIfAbsent(edge.fromId, () => []).add(edge.toId);
  }
  for (final entry in children.entries) {
    entry.value.sort((a, b) {
      final ka = nodeMap[a]!;
      final kb = nodeMap[b]!;
      final kindCmp = ka.kind.index.compareTo(kb.kind.index);
      if (kindCmp != 0) return kindCmp;
      return ka.title.compareTo(kb.title);
    });
  }

  final clusterKeys = layoutClusters.keys.toList();
  final cols = math.max(1, math.sqrt(clusterKeys.length).ceil());
  // 트리 폭을 고려해 클러스터 간격을 넉넉히
  const spacingX = 560.0;
  const spacingY = 520.0;
  const rowGap = 112.0;
  const colGap = 148.0;

  double layoutTree(String nodeId, double xCursor, double originY, int depth) {
    final kids = (children[nodeId] ?? const <String>[])
        .where((id) => !positions.containsKey(id) || depth == 0)
        .where(nodeMap.containsKey)
        .toList();
    // 이미 배치된 자식(다른 부모에 귀속)은 스킵
    final freshKids = <String>[];
    for (final kid in kids) {
      if (!positions.containsKey(kid)) freshKids.add(kid);
    }
    final y = originY + depth * rowGap;
    if (freshKids.isEmpty) {
      positions[nodeId] = Offset(xCursor, y);
      return xCursor + colGap;
    }
    final start = xCursor;
    for (final kid in freshKids) {
      xCursor = layoutTree(kid, xCursor, originY, depth + 1);
    }
    final mid = (start + xCursor - colGap) / 2;
    positions[nodeId] = Offset(mid, y);
    return xCursor;
  }

  for (var i = 0; i < clusterKeys.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final origin = Offset(300 + col * spacingX, 180 + row * spacingY);
    final members = layoutClusters[clusterKeys[i]]!;
    final hubs = members.where((n) => n.kind == GraphNodeKind.group).toList();
    final memories = members.where((n) => n.kind == GraphNodeKind.memory).toList();
    final entityNotes = members.where((n) => n.id.startsWith('entity_note_')).toList();

    String? rootId;
    if (hubs.isNotEmpty) {
      rootId = hubs.first.id;
    } else if (memories.length == 1) {
      rootId = memories.first.id;
    }

    if (rootId != null) {
      // 그룹 아래 기억들을 자식으로 강제 연결(엣지 누락 대비)
      if (hubs.isNotEmpty) {
        final hubId = hubs.first.id;
        final memKids = children.putIfAbsent(hubId, () => <String>[]);
        for (final m in memories) {
          if (!memKids.contains(m.id)) memKids.add(m.id);
        }
      }
      layoutTree(rootId, origin.dx, origin.dy, 0);
    } else if (memories.isNotEmpty) {
      final width = (memories.length - 1) * colGap;
      for (var m = 0; m < memories.length; m++) {
        final memOrigin = Offset(origin.dx - width / 2 + m * colGap, origin.dy);
        layoutTree(memories[m].id, memOrigin.dx, memOrigin.dy, 0);
      }
    }

    // 트리에 못 붙은 위성: 클러스터 하단 행으로 정리
    final unplaced = members.where((n) => !positions.containsKey(n.id) && !n.id.startsWith('entity_note_')).toList();
    if (unplaced.isNotEmpty) {
      var maxY = origin.dy;
      var minX = origin.dx;
      var maxX = origin.dx;
      for (final n in members) {
        final p = positions[n.id];
        if (p == null) continue;
        maxY = math.max(maxY, p.dy);
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
      }
      final rowY = maxY + rowGap;
      final width = (unplaced.length - 1) * colGap;
      final startX = (minX + maxX) / 2 - width / 2;
      for (var s = 0; s < unplaced.length; s++) {
        positions[unplaced[s].id] = Offset(startX + s * colGap, rowY);
      }
    }

    for (final noteNode in entityNotes) {
      String? parentId;
      for (final edge in edges) {
        if (edge.toId == noteNode.id) {
          parentId = edge.fromId;
          break;
        }
      }
      if (parentId == null) continue;
      final parentPos = positions[parentId];
      if (parentPos == null) continue;
      final siblings = entityNotes.where((n) {
        for (final edge in edges) {
          if (edge.toId == n.id && edge.fromId == parentId) return true;
        }
        return false;
      }).toList();
      final index = siblings.indexWhere((n) => n.id == noteNode.id).clamp(0, siblings.length - 1);
      positions[noteNode.id] = parentPos + Offset(0, 56 + index * 48.0);
    }
  }

  for (final node in nodes) {
    positions.putIfAbsent(node.id, () => const Offset(240, 240));
  }
  return positions;
}'''

if old_init not in text:
    raise SystemExit("initialGraphPositions block not found")
text = text.replace(old_init, new_init, 1)

old_painter_ctor = '''class GraphEdgesPainter extends CustomPainter {
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
  });'''

new_painter_ctor = '''class GraphEdgesPainter extends CustomPainter {
  final List<GraphEdgeData> edges;
  final Map<String, Offset> positions;
  final Map<String, GraphNodeData> nodeMap;
  final bool isDark;
  final Set<String>? visibleNodeIds;
  final bool declutter;
  final bool hideLabels;

  GraphEdgesPainter({
    required this.edges,
    required this.positions,
    required this.nodeMap,
    required this.isDark,
    this.visibleNodeIds,
    this.declutter = false,
    this.hideLabels = false,
  });'''

if old_painter_ctor not in text:
    raise SystemExit("GraphEdgesPainter ctor not found")
text = text.replace(old_painter_ctor, new_painter_ctor, 1)

# Replace relation edge painting to straighten + declutter labels
old_relation = '''      if (edge.relationEdge) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.9 : 0.75);
        canvas.drawPath(path, paint);
        if (edge.label != null && edge.label!.isNotEmpty) {
          _paintEdgeLabel(canvas, control, edge.label!);
        }
        continue;
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = edge.color.withValues(alpha: isDark ? 0.55 : 0.45);
      canvas.drawPath(path, linePaint);'''

new_relation = '''      if (edge.relationEdge) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = declutter ? 1.6 : 2.4
          ..color = const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.75 : 0.65);
        // 트리형: 큰 곡선 대신 짧은 벤드로 교차 체감 완화
        final treePath = Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(
            (from.dx + to.dx) / 2,
            (from.dy + to.dy) / 2 - (declutter ? 8 : 18),
            to.dx,
            to.dy,
          );
        canvas.drawPath(treePath, paint);
        if (!hideLabels &&
            edge.label != null &&
            edge.label!.isNotEmpty &&
            (from - to).distance < 260) {
          _paintEdgeLabel(
            canvas,
            Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 10),
            edge.label!,
          );
        }
        continue;
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = declutter ? 1.2 : 1.8
        ..color = edge.color.withValues(alpha: isDark ? 0.45 : 0.4);
      final satPath = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
      canvas.drawPath(satPath, linePaint);'''

if old_relation not in text:
    raise SystemExit("relation edge paint block not found")
text = text.replace(old_relation, new_relation, 1)

old_should = '''  @override
  bool shouldRepaint(covariant GraphEdgesPainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.edges != edges || oldDelegate.isDark != isDark;
  }'''

new_should = '''  @override
  bool shouldRepaint(covariant GraphEdgesPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.edges != edges ||
        oldDelegate.isDark != isDark ||
        oldDelegate.visibleNodeIds != visibleNodeIds ||
        oldDelegate.declutter != declutter ||
        oldDelegate.hideLabels != hideLabels;
  }'''

if old_should not in text:
    raise SystemExit("shouldRepaint not found")
text = text.replace(old_should, new_should, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("graph_layout.dart patched OK")
# verify utf-8 roundtrip
v = path.read_text(encoding="utf-8")
assert "mergeStoredGraphPositions" in v
assert "isGraphHubLikeNode" in v
assert "declutter" in v
print("verify OK", len(v))
