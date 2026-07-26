import json
from pathlib import Path

root = Path("lib/l10n/catalogs")
updates = {
    "ko": {
        "theme_color_hint": "선택한 색에 체크가 표시됩니다",
        "user_guide_subtitle": "앱 언어로 보는 사용방법 · PDF·웹 안내",
        "guide_search_ai": "로그인 + 클라우드(Pro): 「민수랑 먹었던 식당 어디였지?」처럼 자연어로 물으면 의미를 파악해 답합니다.",
        "guide_search_local": "게스트·프라이버시: 기기에 저장된 기억을 자연어·키워드로 찾습니다. 예) 「어머니와 저녁」「광안리 해수욕장」",
        "guide_search_good": "추천: 사람·장소·날짜를 말하듯 입력 — 「연숙이랑 부산」「6월 여행」「장어구이」",
        "guide_search_limit": "팁: 「사진」「오늘」만보다 「오늘 찍은 사진」「어제 엄마랑」처럼 조금만 구체적으로 말해 주세요.",
        "settings_sec_help_sub": "사용방법(선택 언어)",
    },
    "en": {
        "theme_color_hint": "A checkmark shows your selected color",
        "user_guide_subtitle": "In-app guide in your language · PDF & web",
        "guide_search_ai": 'Signed in + Pro cloud: ask in natural language, e.g. "Where did I eat with Min-su?"',
        "guide_search_local": 'Guest & privacy: search on-device memories with natural phrases — e.g. "dinner with mom", "Gwangalli beach".',
        "guide_search_good": 'Try speaking naturally: person, place, date — "Yeonsuk in Busan", "June trip", "grilled eel".',
        "guide_search_limit": 'Tip: prefer "photos I took today" over just "photo" / "today".',
        "settings_sec_help_sub": "How to use (your language)",
    },
    "ja": {
        "theme_color_hint": "選んだ色にチェックが表示されます",
        "user_guide_subtitle": "アプリ言語の使い方 · PDF・Web案内",
        "guide_search_ai": "ログイン + Proクラウド: 「ミンスと食べた店はどこ？」のように自然な言葉で質問できます。",
        "guide_search_local": "ゲスト・プライバシー: 端末内の記憶を自然文・キーワードで検索。例「母と夕食」「広安里海水浴場」",
        "guide_search_good": "うまくいきます: 場所・人・日付 — 例「月影橋」「李舜臣」「6月16日」。自然文も可。",
        "guide_search_limit": "ヒント: 「写真」「今日」だけでなく「今日撮った写真」「昨日お母さんと」のように少し具体的に。",
        "settings_sec_help_sub": "使い方（選択言語）",
        "guide_intro": "タイムライン・検索・関係網・想起通知・写真認識・プライバシーまで、アプリの使い方をまとめました。",
        "guide_title": "MemoryOS 使い方ガイド",
    },
    "zh_Hans": {
        "theme_color_hint": "选中的颜色会显示勾选标记",
        "user_guide_subtitle": "以应用语言查看使用方法 · PDF与网页",
        "guide_search_ai": "登录 + Pro云端: 可用自然语言提问，例如「和敏洙一起吃过的餐厅在哪？」",
        "guide_search_local": "访客与隐私模式: 用自然语言或关键词搜索本机记忆。例「和妈妈吃晚饭」「广安里海水浴场」",
        "guide_search_good": "推荐: 像说话一样输入人物、地点、日期 — 「在釜山和延淑」「六月旅行」「烤鳗鱼」",
        "guide_search_limit": "提示: 比起只说「照片」「今天」，请尽量说「今天拍的照片」「昨天和妈妈」。",
        "settings_sec_help_sub": "使用方法（所选语言）",
        "guide_title": "MemoryOS 使用指南",
    },
    "zh_Hant": {
        "theme_color_hint": "選取的顏色會顯示勾選標記",
        "user_guide_subtitle": "以應用語言查看使用方法 · PDF與網頁",
        "guide_search_ai": "登入 + Pro雲端: 可用自然語言提問，例如「和敏洙一起吃過的餐廳在哪？」",
        "guide_search_local": "訪客與隱私模式: 用自然語言或關鍵字搜尋本機記憶。例「和媽媽吃晚飯」「廣安里海水浴場」",
        "guide_search_good": "推薦: 像說話一樣輸入人物、地點、日期 — 「在釜山和延淑」「六月旅行」「烤鰻魚」",
        "guide_search_limit": "提示: 比起只說「照片」「今天」，請盡量說「今天拍的照片」「昨天和媽媽」。",
        "settings_sec_help_sub": "使用方法（所選語言）",
        "guide_title": "MemoryOS 使用指南",
    },
}

for loc, patch in updates.items():
    path = root / f"{loc}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data.update(patch)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("updated", loc)

base_en = updates["en"]
for loc in ["es", "fr", "de", "pt_BR", "vi"]:
    path = root / f"{loc}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data["theme_color_hint"] = base_en["theme_color_hint"]
    data["user_guide_subtitle"] = base_en["user_guide_subtitle"]
    data["settings_sec_help_sub"] = base_en["settings_sec_help_sub"]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("partial", loc)

# sync into generated_catalogs.dart maps
gen = Path("lib/l10n/generated_catalogs.dart")
text = gen.read_text(encoding="utf-8")
# rebuild from json files for accuracy
catalogs = {}
for p in sorted(root.glob("*.json")):
    catalogs[p.stem] = json.loads(p.read_text(encoding="utf-8"))

def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")

lines = ["/// Auto-synced from lib/l10n/catalogs/*.json\n", "const Map<String, Map<String, String>> generatedLocaleCatalogs = {\n"]
for loc, data in catalogs.items():
    lines.append(f"  '{loc}': {{\n")
    for k in sorted(data.keys()):
        lines.append(f"    '{k}': '{dart_escape(str(data[k]))}',\n")
    lines.append("  },\n")
lines.append("};\n")
gen.write_text("".join(lines), encoding="utf-8")
print("regenerated generated_catalogs.dart", sum(len(v) for v in catalogs.values()), "entries")
