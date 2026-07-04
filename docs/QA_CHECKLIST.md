# Play Store 실기기 QA 체크리스트

기기: `R5CX70Z5LJB` (릴리스 APK · 2026-07-03 점검)

릴리스 APK: `build/app/outputs/flutter-apk/app-release.apk`

## 설치·시작
- [x] 앱 아이콘 실행 시 크래시 없음 (FATAL 없음, 2026-07-03)
- [x] 타임라인 진입 (온보딩 완료 상태)
- [x] 게스트/로컬 모드 정상 (프라이버시 모드 ON, 기기 저장 기억 1건)

## 타임라인 (탭 0)
- [x] 음성 저장: 마이크 탭 → 입력 다이얼로그 표시
- [x] 사진 저장: 카메라 탭 → 시스템 카메라 앱 실행
- [x] 카드 탭 → 상세 시트
- [ ] 당겨서 새로고침 (수동 권장)
- [x] 스와이프 삭제 → 확인 다이얼로그 (취소로 보존)

## 검색 (탭 1)
- [x] 검색 화면 UI 정상
- [ ] 텍스트/음성 검색 응답 (로그인+클라우드 시 추가 확인)
- [ ] 대화 지우기 버튼

## 관계망 (탭 2)
- [x] 그래프 표시 (노드 1개)
- [x] Duplicate key 크래시 없음
- [ ] 노드 탭 → 상세 (수동 권장)

### 편집 → 관계망 신뢰 (P0)
기기에서 아래 시나리오를 순서대로 실행합니다.

1. **새 음성/텍스트 기억** — 예: `철수와 카페에서 이야기` 저장
2. **타임라인 상세 편집** — 본문을 `민수와 카페에서 이야기`로 변경 후 저장
3. **관계망 탭** 확인
   - [ ] 이벤트 허브 제목에 `민수`·`카페` 반영, `철수` 노드 없음
   - [ ] 타임라인 카드 배지에 `철수` 없음, `민수`·`카페`만 표시
4. **앱 완전 종료 후 재시작**
   - [ ] 스낵바: `기존 기억 N건의 관계 태그를 본문에 맞게 갱신` (최초 1회, 해당 시)
   - [ ] 관계망에 옛 이름 노드가 다시 나타나지 않음
5. **설정 → 관계망 데이터 정리**
   - [ ] 정리 권장 배너 (항목 있을 때만)
   - [ ] 정리 실행 후 그래프·타임라인 일관 유지

자동 회귀: `flutter test test/graph_entity_audit_test.dart test/memory_entity_reenrich_test.dart`

## 회상 (탭 3)
- [x] 월별 목록 표시 (2026년 6월)
- [x] 사진 기억 썸네일 표시
- [ ] 타일 탭 → 상세 (수동 권장)

## 설정
- [x] 설정 화면 진입 (앱바 톱니)
- [x] 프라이버시 모드·OCR·테마 옵션 표시
- [ ] 앱 버전 표시 (스크롤 하단 — 수동 확인)
- [ ] 개인정보 처리방침 링크 열기

## 백그라운드·안정성
- [ ] 오프라인 시 상단 배너 (OfflineBanner — 앱 실행 후 비행기 모드로 확인)
- [x] 앱 재시작 후 기억 유지

## P0 자동 회귀 (릴리스 전)
```powershell
flutter test test/graph_entity_audit_test.dart test/memory_entity_reenrich_test.dart test/local_memory_thread_test.dart test/graph_satellite_default_expand_test.dart
.\scripts\qa_release.ps1 -Device <DEVICE_ID>
```

## GitHub Pages (정책·가이드 URL)
```powershell
.\scripts\deploy_github_pages.ps1
# git add / commit / push 후 Settings → Pages → /docs
```

## 스크린샷 (Play Console)
```powershell
.\scripts\capture_store_screenshots.ps1 -Device R3CT80PLETR
```
출력: `store_screenshots/`

| 파일 | 화면 | 상태 |
|------|------|------|
| `01_timeline.png` | 타임라인 | OK |
| `02_search.png` | 검색 엔진 | OK |
| `03_graph.png` | 관계망 | OK |
| `04_replay.png` | 회상 | OK |
| `05_settings.png` | 설정 | OK |

스크린샷은 1080×2640 세로 PNG. Play Console **휴대전화 스크린샷**에 업로드하면 됩니다.
