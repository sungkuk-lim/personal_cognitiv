from pathlib import Path

p = Path("lib/features/graph/graph_layout.dart")
t = p.read_text(encoding="utf-8")
# verify korean intact
assert "나" in t or "본인" in t or "Me" in t
if "memory_entity_cache.dart" not in t:
    t = t.replace(
        "import '../../utils/memory_entity_extract.dart';",
        "import '../../utils/memory_entity_extract.dart';\n"
        "import '../../utils/memory_entity_cache.dart';",
    )
t = t.replace("extractMemoryEntities(", "MemoryEntityCache.bundle(")
p.write_text(t, encoding="utf-8")
print("bundle calls", t.count("MemoryEntityCache.bundle("))
print("extract left", t.count("extractMemoryEntities("))
