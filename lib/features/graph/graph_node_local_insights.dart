import '../../models/graph_ai_snapshot.dart';
import '../../models/memory.dart';
import 'graph_layout.dart';
import 'graph_node_insight.dart';

/// 노드 시트·도움말용 한 줄 요약.
String graphNodeLocalInsightLine({
  required GraphNodeData node,
  required List<Memory> memories,
  required Map<String, GraphMemoryFragment> fragments,
  required String localeCode,
}) {
  final insight = buildGraphNodeInsight(
    node: node,
    connectedMemories: memories,
    allMemories: memories,
    fragments: fragments,
    localeCode: localeCode,
  );
  return insight.summaryLine;
}
