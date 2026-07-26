# -*- coding: utf-8 -*-
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
t = path.read_text(encoding="utf-8", errors="ignore")
descs = re.findall(r'content-desc="([^"]*)"', t)
print("desc_count", len(descs))
for d in descs:
    if d.strip():
        print(d)
