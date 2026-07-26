"""Generate per-locale JSON catalogs from English keys via deep-translator."""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[1]
EN_PATH = ROOT / "lib" / "l10n" / "_en_keys.json"
OUT_DIR = ROOT / "lib" / "l10n" / "catalogs"

# deep-translator / Google language codes
TARGETS = {
    "ja": "ja",
    "zh_Hans": "zh-CN",
    "zh_Hant": "zh-TW",
    "es": "es",
    "fr": "fr",
    "de": "de",
    "pt_BR": "pt",
    "vi": "vi",
}

PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")


def protect(text: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def repl(m: re.Match[str]) -> str:
        tokens.append(m.group(0))
        return f"__PH{len(tokens) - 1}__"

    return PLACEHOLDER_RE.sub(repl, text), tokens


def restore(text: str, tokens: list[str]) -> str:
    out = text
    for i, token in enumerate(tokens):
        for candidate in (f"__PH{i}__", f"__ph{i}__", f"__ PH{i} __", f"__PH {i}__"):
            out = out.replace(candidate, token)
    return out


def translate_batch(items: list[tuple[str, str]], target: str) -> dict[str, str]:
    translator = GoogleTranslator(source="en", target=target)
    result: dict[str, str] = {}
    batch_size = 25
    for start in range(0, len(items), batch_size):
        chunk = items[start : start + batch_size]
        protected = []
        token_map: list[list[str]] = []
        for _, value in chunk:
            p, tokens = protect(value)
            protected.append(p)
            token_map.append(tokens)
        # Join with rare separator so one API call covers many strings.
        joined = "\n<|>\n".join(protected)
        try:
            translated = translator.translate(joined)
        except Exception as e:
            print(f"  batch fail @ {start}: {e}; falling back one-by-one")
            for (key, value), tokens in zip(chunk, token_map):
                try:
                    p, tks = protect(value)
                    tv = restore(translator.translate(p), tks)
                    result[key] = tv
                    time.sleep(0.05)
                except Exception as e2:
                    print(f"    skip {key}: {e2}")
                    result[key] = value
            time.sleep(0.4)
            continue

        parts = translated.split("<|>")
        if len(parts) != len(chunk):
            # fallback: translate individually
            print(f"  split mismatch @ {start}: {len(parts)}/{len(chunk)}; one-by-one")
            for (key, value), tokens in zip(chunk, token_map):
                try:
                    p, tks = protect(value)
                    tv = restore(translator.translate(p), tks)
                    result[key] = tv
                    time.sleep(0.05)
                except Exception as e2:
                    print(f"    skip {key}: {e2}")
                    result[key] = value
        else:
            for (key, _), tokens, part in zip(chunk, token_map, parts):
                result[key] = restore(part.strip(), tokens)
        print(f"  translated {min(start + batch_size, len(items))}/{len(items)}")
        time.sleep(0.35)
    return result


def main() -> None:
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))
    items = list(en.items())
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # Always keep English catalog for fallback merge.
    (OUT_DIR / "en.json").write_text(
        json.dumps(en, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"en catalog: {len(en)} keys")

    for locale_id, google_code in TARGETS.items():
        out_path = OUT_DIR / f"{locale_id}.json"
        if out_path.exists():
            existing = json.loads(out_path.read_text(encoding="utf-8"))
            missing = [k for k in en if k not in existing]
            if not missing:
                print(f"{locale_id}: already complete ({len(existing)})")
                continue
            print(f"{locale_id}: resume {len(missing)} missing")
            todo = [(k, en[k]) for k in missing]
            translated = translate_batch(todo, google_code)
            existing.update(translated)
            out_path.write_text(
                json.dumps(existing, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        else:
            print(f"{locale_id}: translating all ({len(items)}) → {google_code}")
            translated = translate_batch(items, google_code)
            # Ensure every key exists (fallback to English).
            for k, v in en.items():
                translated.setdefault(k, v)
            out_path.write_text(
                json.dumps(translated, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        print(f"{locale_id}: wrote {out_path}")


if __name__ == "__main__":
    main()
