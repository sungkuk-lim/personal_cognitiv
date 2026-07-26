from pathlib import Path
import subprocess
import re

t = Path("lib/features/graph/graph_layout.dart").read_text(encoding="utf-8")
for m in re.finditer(r"GraphNodeKind\.food => .+", t):
    print("file:", repr(m.group(0)[:100]))
print("has 음식", "음식" in t)
print("has 본인", "본인" in t)
blob = subprocess.check_output(["git", "show", "HEAD:lib/features/graph/graph_layout.dart"]).decode("utf-8")
print("blob has 음식", "음식" in blob)
print("blob has pet,", "\n  pet," in blob or "pet," in blob)
# find kind label section in blob
idx = blob.find("GraphNodeKind.food =>")
print("blob snippet", repr(blob[idx : idx + 80]))
