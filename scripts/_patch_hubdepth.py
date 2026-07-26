from pathlib import Path

p = Path("lib/features/graph/graph_layout.dart")
t = p.read_text(encoding="utf-8")

if "organization_hierarchy.dart" not in t:
    t = t.replace(
        "import '../../utils/memory_graph_semantics.dart';",
        "import '../../utils/memory_graph_semantics.dart';\n"
        "import '../../utils/organization_hierarchy.dart';",
    )

if "hubDepth" not in t:
    raise SystemExit("hubDepth missing — GraphNodeData patch failed")

if "graphKindForOrgKind" not in t:
    insert = '''
/// 조직 계층 노드 → 그래프 노드 종류.
GraphNodeKind graphKindForOrgKind(OrganizationNodeKind kind) {
  return switch (kind) {
    OrganizationNodeKind.organization => GraphNodeKind.organization,
    OrganizationNodeKind.person => GraphNodeKind.person,
    OrganizationNodeKind.project => GraphNodeKind.eventHub,
    OrganizationNodeKind.place => GraphNodeKind.place,
    OrganizationNodeKind.event => GraphNodeKind.event,
    OrganizationNodeKind.activity => GraphNodeKind.activity,
    OrganizationNodeKind.food => GraphNodeKind.food,
    OrganizationNodeKind.pet => GraphNodeKind.pet,
    OrganizationNodeKind.item => GraphNodeKind.content,
  };
}

'''
    t = t.replace("class GraphEdgeData {", insert + "class GraphEdgeData {")

t = t.replace("GraphNodeKind.pet => AppGraphColors.person,", "GraphNodeKind.pet => AppGraphColors.pet,")

# keyword switch pet case
if "MemoryKeywordKind.pet =>" not in t:
    t = t.replace(
        "MemoryKeywordKind.person => GraphNodeKind.person,\n          MemoryKeywordKind.place => GraphNodeKind.place,",
        "MemoryKeywordKind.person => GraphNodeKind.person,\n"
        "          MemoryKeywordKind.pet => GraphNodeKind.pet,\n"
        "          MemoryKeywordKind.place => GraphNodeKind.place,",
    )

p.write_text(t, encoding="utf-8")
print("ok hubDepth", "hubDepth" in t)
print("ok graphKind", "graphKindForOrgKind" in t)
print("ok pet color", "AppGraphColors.pet" in t)
