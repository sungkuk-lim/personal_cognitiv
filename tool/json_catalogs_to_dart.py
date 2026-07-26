"""Convert locale JSON catalogs into a single Dart source file."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_DIR = ROOT / "lib" / "l10n" / "catalogs"
OUT = ROOT / "lib" / "l10n" / "generated_catalogs.dart"

LOCALES = ["en", "ko", "ja", "zh_Hans", "zh_Hant", "es", "fr", "de", "pt_BR", "vi"]


def dart_escape(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "")
        .replace("$", "\\$")
    )


def map_literal(data: dict[str, str]) -> str:
    lines = ["{"]
    for key in sorted(data.keys()):
        lines.append(f"  '{dart_escape(key)}': '{dart_escape(data[key])}',")
    lines.append("}")
    return "\n".join(lines)


def main() -> None:
    # Ensure en/ko exist in catalogs folder.
    catalogs: dict[str, dict[str, str]] = {}
    for locale in LOCALES:
        path = CATALOG_DIR / f"{locale}.json"
        if not path.exists():
            raise SystemExit(f"missing {path}")
        catalogs[locale] = json.loads(path.read_text(encoding="utf-8"))

    parts = [
        "// GENERATED FILE — do not edit by hand.",
        "// Regenerate: python tool/generate_locale_catalogs.py && python tool/json_catalogs_to_dart.py",
        "",
        "const Map<String, Map<String, String>> generatedLocaleCatalogs = {",
    ]
    for locale in LOCALES:
        parts.append(f"  '{locale}': {map_literal(catalogs[locale])},")
    parts.append("};")
    parts.append("")
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
