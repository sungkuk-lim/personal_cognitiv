import json
import re
from pathlib import Path

root = Path("lib/l10n/catalogs")
gen_path = Path("lib/l10n/generated_catalogs.dart")

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
        "guide_graph": "関係網: 上部で「人物」・「記憶」レンズを選びます。人物・場所サテライトにも関連写真・動画のサムネイルが表示されます。ピンチで拡大・移動できます。",
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
        "guide_graph": "关系网: 顶部选择「人物」或「记忆」镜头。人物与地点卫星也会显示相关照片/视频缩略图。双指缩放与平移。",
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
        "guide_graph": "關係網: 頂部選擇「人物」或「記憶」鏡頭。人物與地點衛星也會顯示相關照片/影片縮圖。雙指縮放與平移。",
    },
}

for loc in ["es", "fr", "de", "pt_BR", "vi"]:
    updates[loc] = {
        "theme_color_hint": updates["en"]["theme_color_hint"],
        "user_guide_subtitle": updates["en"]["user_guide_subtitle"],
        "settings_sec_help_sub": updates["en"]["settings_sec_help_sub"],
    }

for loc, patch in updates.items():
    path = root / f"{loc}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data.update(patch)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("json", loc, len(patch))

text = gen_path.read_text(encoding="utf-8")


def dart_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def upsert_key(block: str, key: str, value: str) -> str:
    pattern = rf"('{re.escape(key)}': )'((?:\\'|[^'])*)'"
    repl = rf"\1'{dart_escape(value)}'"
    if re.search(pattern, block):
        return re.sub(pattern, repl, block, count=1)
    # insert before closing of map — before last newline of block
    insert = f"    '{key}': '{dart_escape(value)}',\n"
    # block ends with spaces before nothing; find last entry
    return block.rstrip() + "\n" + insert


# Split locale maps by top-level keys like 'en': {
locale_pat = re.compile(r"  '((?:en|ko|ja|zh_Hans|zh_Hant|es|fr|de|pt_BR|vi))': \{")
matches = list(locale_pat.finditer(text))
parts = []
last = 0
for i, m in enumerate(matches):
    start = m.start()
    end = matches[i + 1].start() if i + 1 < len(matches) else text.rfind("};")
    parts.append((m.group(1), start, end))

out = []
cursor = 0
for loc, start, end in parts:
    out.append(text[cursor:start])
    block = text[start:end]
    if loc in updates:
        # extract inner map only
        brace = block.find("{")
        head = block[: brace + 1]
        # body until matching close at indent 2
        body = block[brace + 1 :]
        # body ends with `  },\n` or `  }`
        close_idx = body.rfind("},")
        if close_idx < 0:
            close_idx = body.rfind("}")
        inner = body[:close_idx]
        tail = body[close_idx:]
        for k, v in updates[loc].items():
            inner = upsert_key(inner, k, v)
        block = head + inner + tail
        print("patched gen", loc)
    out.append(block)
    cursor = end
out.append(text[cursor:])
gen_path.write_text("".join(out), encoding="utf-8")
print("done")
