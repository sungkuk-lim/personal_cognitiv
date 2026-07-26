# -*- coding: utf-8 -*-
import re
import sys
from pathlib import Path

t = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
for m in re.finditer(
    r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', t
):
    d, a, b, c, e = m.groups()
    if d.strip():
        print(f"{d} @ {(int(a)+int(c))//2},{(int(b)+int(e))//2}")
