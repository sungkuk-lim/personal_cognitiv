from pathlib import Path
import subprocess
import re

# 1) Restore clean UTF-8 from git
blob = subprocess.check_output(["git", "show", "HEAD:lib/features/graph/graph_layout.dart"])
text = blob.decode("utf-8")

# 2) Apply all patches in memory
# pet enum
if "\n  pet,\n" not in text:
    text = text.replace("  person,\n  place,", "  person,\n  pet,\n  place,")

# imports
if "memory_entity_cache.dart" not in text:
    text = text.replace(
        "import '../../utils/memory_entity_extract.dart';",
        "import '../../utils/memory_entity_extract.dart';\n"
        "import '../../utils/memory_entity_cache.dart';",
    )
if "organization_hierarchy.dart" not in text:
    text = text.replace(
        "import '../../utils/memory_graph_semantics.dart';",
        "import '../../utils/memory_graph_semantics.dart';\n"
        "import '../../utils/organization_hierarchy.dart';",
    )

text = text.replace("extractMemoryEntities(", "MemoryEntityCache.bundle(")

# hubDepth on GraphNodeData
if "hubDepth" not in text:
    text = text.replace(
        "  final String layoutClusterId;\n  /// 위성 접힘 시 배지",
        "  final String layoutClusterId;\n"
        "  /// 관계망 허브 깊이 (0=루트).\n"
        "  final int? hubDepth;\n"
        "  /// 위성 접힘 시 배지",
    )
    text = text.replace(
        "    required this.layoutClusterId,\n    this.satelliteBadge,\n  });",
        "    required this.layoutClusterId,\n    this.hubDepth,\n    this.satelliteBadge,\n  });",
    )

# pet in color switch
if "GraphNodeKind.pet =>" not in text.split("graphNodeKindColor")[1][:500]:
    text = text.replace(
        "    GraphNodeKind.person => AppGraphColors.person,\n    GraphNodeKind.place => AppGraphColors.place,",
        "    GraphNodeKind.person => AppGraphColors.person,\n"
        "    GraphNodeKind.pet => AppGraphColors.pet,\n"
        "    GraphNodeKind.place => AppGraphColors.place,",
    )

# keyword pet
if "MemoryKeywordKind.pet =>" not in text:
    text = text.replace(
        "          MemoryKeywordKind.person => GraphNodeKind.person,\n          MemoryKeywordKind.place => GraphNodeKind.place,",
        "          MemoryKeywordKind.person => GraphNodeKind.person,\n"
        "          MemoryKeywordKind.pet => GraphNodeKind.pet,\n"
        "          MemoryKeywordKind.place => GraphNodeKind.place,",
    )

# kind labels ko/en
if "GraphNodeKind.pet => '반려'" not in text and "GraphNodeKind.pet => 'Pet'" not in text:
    text = text.replace(
        "      GraphNodeKind.person => '사람',\n      GraphNodeKind.place => '장소',",
        "      GraphNodeKind.person => '사람',\n      GraphNodeKind.pet => '반려',\n      GraphNodeKind.place => '장소',",
    )
    text = text.replace(
        "    GraphNodeKind.person => 'Person',\n    GraphNodeKind.place => 'Place',",
        "    GraphNodeKind.person => 'Person',\n    GraphNodeKind.pet => 'Pet',\n    GraphNodeKind.place => 'Place',",
    )

# graphKindForOrgKind
if "graphKindForOrgKind" not in text:
    fn = '''
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
    text = text.replace("class GraphEdgeData {", fn + "class GraphEdgeData {")

out = Path("lib/features/graph/graph_layout.dart")
out.write_text(text, encoding="utf-8", newline="\n")

# verify
v = out.read_text(encoding="utf-8")
assert "음식" in v or "Food" in v
assert "hubDepth" in v
assert "graphKindForOrgKind" in v
assert "\n  pet,\n" in v
assert v.count("MemoryEntityCache.bundle(") >= 1
print("RESTORED_OK", len(v), "bundles", v.count("MemoryEntityCache.bundle("))
