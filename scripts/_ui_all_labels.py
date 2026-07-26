# -*- coding: utf-8 -*-
import re
import sys
from pathlib import Path

t = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
# include text= and content-desc=
pat = re.compile(
    r'(?:text|content-desc)="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"|'
    r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*(?:text|content-desc)="([^"]*)"'
)
seen = set()
for m in re.finditer(
    r'class="([^"]*)"[^>]*package="[^"]*"[^>]*(?:text="([^"]*)")?[^>]*(?:content-desc="([^"]*)")?[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
    t,
):
    cls, text, desc, a, b, c, e = m.groups()
    label = (desc or text or "").strip()
    if not label:
        continue
    key = (label, a, b, c, e)
    if key in seen:
        continue
    seen.add(key)
    print(f"{label} | {cls.split('.')[-1]} @ {(int(a)+int(c))//2},{(int(b)+int(e))//2}")
