#!/usr/bin/env python3
"""Upload Play Store listing (ko-KR) + graphics. Uses service account."""
from __future__ import annotations

import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = "com.theNext.personal_cognitive"
SA = "secrets/revenuecat-play-sa.json"
SCOPE = ["https://www.googleapis.com/auth/androidpublisher"]

TITLE = "MemoryOS · 모담넷"
SHORT = (
    "말한 기억을 로컬 관계망으로 정리하고, Pro에서 AI 검색·인사이트로 다시 떠올리는 개인 메모리 앱"
)
# Play shortDescription max 80 chars
if len(SHORT) > 80:
    SHORT = SHORT[:80]

FULL = """MemoryOS(모담넷)는 폴더 없이 기억을 쌓고, 관계망으로 사람·장소·사건을 연결해 다시 찾는 개인 인지 보조 앱입니다.

■ 로컬 vs AI (핵심 구조)
• 무료·기기: 음성·사진 저장, 관계망 골격(허브·위성·관계선), 키워드 검색 — 즉시 기기에서 동작
• Pro·클라우드: 의미 검색·AI 답변, 관계 인사이트, 복합 질의, Graph AI 조각, 사진 AI 분석
• 관계망은 항상 로컬 규칙으로 먼저 구성되고, AI는 보조(Pro + 설정 ON 시)

■ 핵심 기능
• 음성 저장: 말하면 분류·요약해 저장
• 사진·OCR: 촬영한 글자·장면을 기억으로 보관
• 관계망: 사람·장소·키워드 연결을 시각화 (로컬 즉시)
• 대화형 검색(Pro): "지난달 제주도 뭐 했지?"처럼 질문
• 회상 타임라인: 월별로 기억을 다시 보기
• 선제적 소환: 과거 방문 장소에서 잊은 기억 알림

■ 프라이버시
• 게스트·프라이버시 모드: 기기에만 저장 가능
• 개인정보 처리방침·이용약관: 앱 내에서 확인
• 클라우드 동기화는 로그인 후 선택 사용

■ 요금
앱 무료 · MemoryOS Pro(월/연 구독): 클라우드·AI 검색·인사이트·Graph AI·사진 분석
무료: 기기 저장·로컬 관계망·키워드 검색·장소 회상 알림

개인정보 처리방침: https://sungkuk-lim.github.io/personal_cognitiv/privacy.html
이용약관: https://sungkuk-lim.github.io/personal_cognitiv/terms.html
이용 가이드: https://sungkuk-lim.github.io/personal_cognitiv/user_guide.html

개발: theNext
"""


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    icon = root / "store_assets" / "icon_512.png"
    feature = root / "store_assets" / "feature_graphic_1024x500.png"
    shots_dir = root / "store_assets" / "phone_screenshots"
    if not shots_dir.is_dir():
        shots_dir = root / "store_screenshots"

    creds = service_account.Credentials.from_service_account_file(SA, scopes=SCOPE)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    edit = service.edits().insert(body={}, packageName=PACKAGE).execute()
    edit_id = edit["id"]
    print(f"edit={edit_id}")

    service.edits().listings().update(
        packageName=PACKAGE,
        editId=edit_id,
        language="ko-KR",
        body={
            "language": "ko-KR",
            "title": TITLE,
            "shortDescription": SHORT,
            "fullDescription": FULL,
        },
    ).execute()
    print("listing updated")

    if icon.is_file():
        media = MediaFileUpload(str(icon), mimetype="image/png")
        service.edits().images().upload(
            packageName=PACKAGE,
            editId=edit_id,
            language="ko-KR",
            imageType="icon",
            media_body=media,
        ).execute()
        print("icon uploaded")

    if feature.is_file():
        media = MediaFileUpload(str(feature), mimetype="image/png")
        service.edits().images().upload(
            packageName=PACKAGE,
            editId=edit_id,
            language="ko-KR",
            imageType="featureGraphic",
            media_body=media,
        ).execute()
        print("featureGraphic uploaded")

    # phone screenshots (replace existing by uploading; API adds)
    if shots_dir.is_dir():
        shots = sorted(shots_dir.glob("0*.png"))[:8]
        for i, shot in enumerate(shots, 1):
            media = MediaFileUpload(str(shot), mimetype="image/png")
            service.edits().images().upload(
                packageName=PACKAGE,
                editId=edit_id,
                language="ko-KR",
                imageType="phoneScreenshots",
                media_body=media,
            ).execute()
            print(f"screenshot {i}: {shot.name}")

    try:
        commit = service.edits().commit(packageName=PACKAGE, editId=edit_id).execute()
        print(f"COMMITTED {commit.get('id')}")
        return 0
    except Exception as e:
        print(f"commit failed: {e}", file=sys.stderr)
        print(
            "Listing/images may be in an uncommitted edit. "
            "Play Console → 스토어 등록정보에서 저장하거나 SA에 출시 권한을 주세요.",
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
