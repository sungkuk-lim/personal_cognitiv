"""Keep product brand strings consistent across locale catalogs."""
from __future__ import annotations

import json
import re
from pathlib import Path

CATALOG_DIR = Path(__file__).resolve().parents[1] / "lib" / "l10n" / "catalogs"

# Keys that should keep English product naming.
BRAND_KEYS = {
    "pro_plan": "MemoryOS Pro",
    "pro_title": "MemoryOS Pro",
    "pro_manage": None,  # may contain MemoryOS — handled by regex
}

BRAND_FIXES = [
    (re.compile(r"メモリOS|メモリーOS|内存操作系统|記憶體作業系統|Memoria OS|MémoireOS|Memória OS|Bộ nhớ OS", re.I), "MemoryOS"),
    (re.compile(r"Memory OS", re.I), "MemoryOS"),
]


def fix_value(value: str) -> str:
    out = value
    for pattern, repl in BRAND_FIXES:
        out = pattern.sub(repl, out)
    return out


def main() -> None:
    for path in sorted(CATALOG_DIR.glob("*.json")):
        if path.name in {"en.json", "ko.json"}:
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = 0
        for key, value in list(data.items()):
            if key in {"pro_plan", "pro_title"}:
                if value != "MemoryOS Pro":
                    data[key] = "MemoryOS Pro"
                    changed += 1
                continue
            fixed = fix_value(value)
            if fixed != value:
                data[key] = fixed
                changed += 1
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"{path.name}: fixed {changed}")


if __name__ == "__main__":
    main()
