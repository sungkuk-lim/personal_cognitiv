from pathlib import Path
import subprocess

# Restore clean UTF-8 from git HEAD
blob = subprocess.check_output(["git", "show", "HEAD:lib/features/graph/graph_layout.dart"])
# verify
text = blob.decode("utf-8")
assert "음식" in text or "Food" in text
Path("lib/features/graph/graph_layout.dart").write_bytes(blob)
print("restored bytes", len(blob))

# Re-apply: add pet enum + cache import + MemoryEntityCache.bundle
t = Path("lib/features/graph/graph_layout.dart").read_text(encoding="utf-8")
if "\n  pet,\n" not in t:
    t = t.replace(
        "  person,\n  place,",
        "  person,\n  pet,\n  place,",
    )
if "memory_entity_cache.dart" not in t:
    t = t.replace(
        "import '../../utils/memory_entity_extract.dart';",
        "import '../../utils/memory_entity_extract.dart';\n"
        "import '../../utils/memory_entity_cache.dart';",
    )
t = t.replace("extractMemoryEntities(", "MemoryEntityCache.bundle(")

# Ensure pet in color / label switches if missing
if "GraphNodeKind.pet =>" not in t:
    # color switch
    t = t.replace(
        "    GraphNodeKind.person => AppGraphColors.person,\n    GraphNodeKind.place => AppGraphColors.place,",
        "    GraphNodeKind.person => AppGraphColors.person,\n"
        "    GraphNodeKind.pet => AppGraphColors.person,\n"
        "    GraphNodeKind.place => AppGraphColors.place,",
    )
    # keyword hub switch
    t = t.replace(
        "          MemoryKeywordKind.person => GraphNodeKind.person,\n          MemoryKeywordKind.place => GraphNodeKind.place,",
        "          MemoryKeywordKind.person => GraphNodeKind.person,\n"
        "          MemoryKeywordKind.pet => GraphNodeKind.pet,\n"
        "          MemoryKeywordKind.place => GraphNodeKind.place,",
    )
    # Korean labels
    t = t.replace(
        "      GraphNodeKind.person => '사람',\n      GraphNodeKind.place => '장소',",
        "      GraphNodeKind.person => '사람',\n"
        "      GraphNodeKind.pet => '반려',\n"
        "      GraphNodeKind.place => '장소',",
    )
    # English labels
    t = t.replace(
        "    GraphNodeKind.person => 'Person',\n    GraphNodeKind.place => 'Place',",
        "    GraphNodeKind.person => 'Person',\n"
        "    GraphNodeKind.pet => 'Pet',\n"
        "    GraphNodeKind.place => 'Place',",
    )

Path("lib/features/graph/graph_layout.dart").write_text(t, encoding="utf-8")
check = Path("lib/features/graph/graph_layout.dart").read_text(encoding="utf-8")
print("utf8 ok", "음식" in check or "Food" in check)
print("pet enum", "\n  pet,\n" in check)
print("bundle", check.count("MemoryEntityCache.bundle("))
print("extract left", check.count("extractMemoryEntities("))
