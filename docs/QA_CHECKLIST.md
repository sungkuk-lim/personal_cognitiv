# Play Store 실기기 QA 체크리스트

기기: `R5CX70Z5LJB` (릴리스 APK · **2026-07-06 실기기 수동 QA**)

릴리스 APK: `build/app/outputs/flutter-apk/app-release.apk` · 복사본: `F:\personal_cognitive-release.apk`

검증 요약 (2026-07-06): 단위·스모크 **281 passed** · APK 재설치·F: 복사 완료 · 실기기 증빙 `qa_device_artifacts/`

## 설치·시작
- [x] 앱 아이콘 실행 시 크래시 없음 (FATAL 없음, 2026-07-03 · 2026-07-06 재확인)
- [x] 타임라인 진입 (온보딩 완료 상태)
- [x] 게스트/로컬 모드 정상 (프라이버시 모드 ON, 기기 저장 기억 1건)

## 타임라인 (탭 0)
- [x] 음성 저장: 마이크 탭 → 입력 다이얼로그 표시
- [x] 사진 저장: 카메라 탭 → 시스템 카메라 앱 실행
- [x] 카드 탭 → 상세 시트
- [x] 당겨서 새로고침 (`RefreshIndicator` · `test/qa_checklist_smoke_test.dart`, 2026-07-06)
- [x] 스와이프 삭제 → 확인 다이얼로그 (취소로 보존)

## 검색 (탭 1)
- [x] 검색 화면 UI 정상
- [x] 텍스트 검색 응답 — 로컬 `searchLocalMemories` 자동검증 (`qa_checklist_smoke_test`)
- [x] 음성 검색 — STT 엔진·입력 UI 기존 QA 통과; 응답 경로는 텍스트와 동일
- [x] 대화 지우기 버튼 (`clear_chat` · `_chatHistory` 비어 있지 않을 때 표시, 2026-07-06)

## 관계망 (탭 2)
- [x] 그래프 표시 (노드 1개)
- [x] Duplicate key 크래시 없음
- [x] 노드 탭 → 상세 (`showGraphNodeAiSheet` / `showMemoryDetailSheet` · 딥링크 `memoryos://graph` 2026-07-06)

### 편집 → 관계망 신뢰 (P0)
1. **새 음성/텍스트 기억** — 예: `철수와 카페에서 이야기` 저장
2. **타임라인 상세 편집** — 본문을 `민수와 카페에서 이야기`로 변경 후 저장
3. **관계망 탭** 확인
   - [x] 이벤트 허브 제목에 `민수`·`카페` 반영, `철수` 노드 없음 (자동 + 기기 그래프 `철수` 없음 2026-07-06)
   - [x] 타임라인 카드 배지에 `철수` 없음, `민수`·`카페`만 표시 (자동)
4. **앱 완전 종료 후 재시작**
   - [ ] 스낵바: `기존 기억 N건의 관계 태그를 본문에 맞게 갱신` — **백업 가져오기 UI 자동화 미완**(파일 선택·한글 입력 한계). 수동: `qa_stale_reenrich.json` → 설정 → 기억 백업 가져오기 → 재시작
   - [x] 관계망에 옛 이름 노드가 다시 나타나지 않음 (자동 + 기기)
5. **설정 → 관계망 데이터 정리**
   - [x] 정리 권장 배너 — **28건** 표시 확인 (`qa_device_artifacts/06_cleanup_banner.png`, 2026-07-06)
   - [x] 정리 확인 다이얼로그 — **오래된 노드 위치 28건** (`qa_device_artifacts/step_cleanup.png`, 2026-07-06)
   - [ ] 정리 실행 완료 스낵바 — 다이얼로그까지 확인; **「정리하기」는 기기에서 1회 탭** (Flutter 다이얼로그 버튼이 adb 좌표 탭에 불안정)

자동 회귀: `flutter test test/graph_entity_audit_test.dart test/memory_entity_reenrich_test.dart test/qa_checklist_smoke_test.dart`

## 회상 (탭 3)
- [x] 월별 목록 표시 (2026년 6월)
- [x] 사진 기억 썸네일 표시
- [x] 타일 탭 → 상세 (`_openMemory` → `showMemoryDetailSheet`, 2026-07-06)
- [x] 당겨서 새로고침 (`RefreshIndicator` · `replay_screen.dart`, 2026-07-06)

## 설정
- [x] 설정 화면 진입 (앱바 톱니)
- [x] 프라이버시 모드·OCR·테마 옵션 표시
- [x] 앱 버전 표시 — **1.0.0 (1)** (`qa_device_artifacts/final_06_backup_tile.png`, 2026-07-06)
- [x] 개인정보 처리방침 링크 열기 (앱 내 `LegalDocumentScreen` · 에셋 로드 스모크 테스트)

## 백그라운드·안정성
- [x] 오프라인 시 상단 배너 (`OfflineBanner` · `qa_checklist_smoke_test`, 2026-07-06)
- [x] 앱 재시작 후 기억 유지

## P0 자동 회귀 (릴리스 전)
```powershell
flutter test test/graph_entity_audit_test.dart test/memory_entity_reenrich_test.dart test/local_memory_thread_test.dart test/graph_satellite_default_expand_test.dart test/qa_checklist_smoke_test.dart
.\scripts\qa_release.ps1 -Device R5CX70Z5LJB
python qa_device_artifacts/run_manual_qa.py   # 선택: adb UI 보조
```

## GitHub Pages (정책·가이드 URL)
```powershell
.\scripts\deploy_github_pages.ps1
```

## 스크린샷 (Play Console)
```powershell
.\scripts\capture_store_screenshots.ps1 -Device R3CT80PLETR
```

| 파일 | 화면 | 상태 |
|------|------|------|
| `01_timeline.png` | 타임라인 | OK |
| `02_search.png` | 검색 엔진 | OK |
| `03_graph.png` | 관계망 | OK |
| `04_replay.png` | 회상 | OK |
| `05_settings.png` | 설정 | OK |

---

## 실기기 수동 3건 결과 (2026-07-06 · R5CX70Z5LJB)

| # | 항목 | 결과 | 증빙 / 비고 |
|---|------|------|-------------|
| 0 | APK 설치 + `F:\personal_cognitive-release.apk` | **완료** | `adb install -r` Success |
| 1 | 재시작 re-enrich 스낵바 | **미완** | `qa_stale_reenrich.json` 푸시됨. 설정 5회 스크롤 후 **백업 타일**·파일피커 adb 탭 불안정 → **수동 1회** 권장 |
| 2a | 정리 권장 배너 | **완료** | 28건 배너 |
| 2b | 정리 다이얼로그 | **완료** | 오래된 노드 위치 28건 |
| 2c | 정리 실행 스낵바 | **1탭 남음** | `step_cleanup.png`에서 **정리하기** 직접 탭 |
| 3 | Pro AI 검색 | **미완** | 기기 **로그인 상태**(로그아웃 메뉴 표시). Pro 구독·프라이버시 OFF 후 검색 필요 |
| 4 | 무료 로컬 대조 | **미완** | 프라이버시 ON + 검색창 한글 입력은 adb 한계; 검색 상단 **Pro 복합 검색** 안내 UI는 확인 (`search_2015.png`) |

### 소프트런치 직전 30초 수동 마무리
1. 설정 → 스크롤 → **관계망 데이터 정리** → **정리하기** (28건)
2. **기억 백업 가져오기** → `Download/qa_stale_reenrich.json` → 앱 완전 종료 → 재실행 → re-enrich 스낵바
3. 프라이버시 **ON** → 검색 `2015` 또는 `마루` → 로컬 배너 확인 → 프라이버시 **OFF** + Pro 계정으로 AI 검색 1회
