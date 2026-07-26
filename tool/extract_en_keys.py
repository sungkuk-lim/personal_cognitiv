import json
import re
from pathlib import Path

text = Path("lib/l10n/translations.dart").read_text(encoding="utf-8")
m = re.search(r"'en': \{([\s\S]*?)\n  \},\n\};", text)
if not m:
    raise SystemExit("en block not found")
block = m.group(1)
pairs = re.findall(r"'((?:\\'|[^'])*)'\s*:\s*'((?:\\'|[^'])*)'", block)
obj = {k: v.replace("\\'", "'") for k, v in pairs}
out = Path("lib/l10n/_en_keys.json")
out.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"wrote {len(obj)} keys to {out}")
