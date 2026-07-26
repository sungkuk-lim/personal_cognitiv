# 소프트 런치 전 7일 체크리스트

**목표:** 1-star 리뷰 방지 P0만 완료 후 Play 비공개/소규모 공개  
**기준일:** 2026-07-12  
**종합 가이드:** [TOTAL.md](TOTAL.md) · [MODAMNET_INDEX.md](MODAMNET_INDEX.md) · [GITHUB_PAGES.md](GITHUB_PAGES.md)

**역할 구분**
- **Agent**: 레포 코드·문서·스크립트·로컬 빌드/테스트
- **Human**: GitHub Pages 설정, Play Console, RevenueCat, AAB 업로드·테스터

**공개 정책 URL (현재 라이브)**
```
https://sungkuk-lim.github.io/personal_cognitiv/privacy.html
https://sungkuk-lim.github.io/personal_cognitiv/terms.html
```
앱 기본값: `lib/core/app_urls.dart` (동일 호스트)

**결제 상품 ID (코드 고정)** — `lib/core/subscription_config.dart`
- 월간: `memoryos_pro_monthly`
- 연간: `memoryos_pro_annual`
- Entitlement: `pro`
- Paywall: RevenueCat 키·오퍼링 없으면 `pro_store_pending` UI만 (하드킬스위치 없음)

---

## D-7 · 법적·스토어

| # | 작업 | Agent / Human | 완료 |
|---|------|---------------|------|
| 1 | `docs/privacy.html` · `terms.html` · `.nojekyll` 레포 준비 | Agent | ☑ |
| 1b | GitHub Pages: Settings → Deploy from branch → `main` / `/docs` | Human | ☑ 라이브 확인 2026-07-26 |
| 2 | Play Console 개인정보처리방침 URL 등록 (위 라이브 URL) | Human | ☑ 앱 콘텐츠 선언 완료 2026-07-25 |
| 3 | 스크린샷 5장 (`scripts/capture_store_screenshots.ps1`) → `store_screenshots/` | Agent(기기) / Human(Play 업로드) | ☑ Play 등록 5장 확인 2026-07-26 |
| 4 | 짧은/전체 설명 — **무료=로컬, Pro=AI** ([STORE_READINESS.md](STORE_READINESS.md)) | Agent 문구 점검 | ☑ `MemoryOS · 모담넷` 반영·검토중 2026-07-25 |

## D-6 · 결제·클라우드 E2E

| # | 작업 | Agent / Human | 완료 |
|---|------|---------------|------|
| 5 | Play 구독 `memoryos_pro_monthly` / `annual` 활성 | Human | ☑ ACTIVE 확인 2026-07-26 |
| 6 | RevenueCat entitlement `pro` + 웹훅 → Supabase | Human | ☐ 콘솔 재확인 필요 |
| 7 | 실기기: Paywall → 결제(테스트) → Pro 검색·AI 1회 (`REVENUECAT_ANDROID_KEY` 빌드) | Human | ☐ |
| 8 | 실기기: 게스트 모드 — 결제 없이 로컬 저장·관계망 | Human(확인) / Agent(코드) | ☐ |

## D-5 · 신뢰 P0 (코드 반영됨 → 실기기 확인)

| # | 작업 | Agent / Human | 완료 |
|---|------|---------------|------|
| 9 | 기억 상세 → **관계 태그 수정** → 관계망 반영 | Human 실기기 | ☐ |
| 10 | 설정 → **백업보내기/가져오기** JSON | Human 실기기 | ☐ |
| 11 | 본문 편집 후 옛 이름 노드 없음 | Human 실기기 | ☐ |
| 12 | 검색: 무료 시 **로컬 결과 배너** 표시 | Human 실기기 | ☐ |

## D-4 · 핵심 루프 QA

```powershell
flutter test
.\scripts\qa_release.ps1 -Device R5CX70Z5LJB
```

| # | 시나리오 | Agent / Human | 완료 |
|---|----------|---------------|------|
| 13 | 음성 저장 → 타임라인 | Human | ☐ |
| 14 | 사진·동영상 → 회상 썸네일 | Human | ☐ |
| 15 | 회상 길게 누르기 → 관계 미리보기 | Human | ☐ |
| 16 | 관계망 기억 포커스 | Human | ☐ |
| 17 | 앱 재시작 후 데이터 유지 | Human | ☐ |

## D-3 · 안정성

| # | 작업 | Agent / Human | 완료 |
|---|------|---------------|------|
| 18 | Firebase Crashlytics 콘솔 활성·테스트 크래시 1회 | Human | ☐ |
| 19 | 오프라인 배너·비행기 모드 저장 | Human | ☐ |
| 20 | 위치 회상 권한 거부 시 앱 정상 동작 | Agent(UX) / Human(확인) | ☐ |

## D-2 · 빌드·배포

| # | 작업 | Agent / Human | 완료 |
|---|------|---------------|------|
| 21 | `scripts/build_bundle.ps1` / `flutter build appbundle` AAB (`key.properties` 있음) | Agent(로컬) | ☑ 2026-07-25 `1.0.12+16` AAB |
| 22 | 내부 테스트 트랙 업로드 | Human / Agent | ☑ `1.0.12 (16)` completed 2026-07-25 |
| 23 | 테스터 3~5명 초대 | Human | ☐ 그룹 `modamnet-testers` 생성 · 멤버·비공개 테스트 연결 대기 |

## D-1 · D-Day

| # | 작업 | Agent / Human | 완료 |
|---|------|---------------|------|
| 24 | 테스터 피드백 P0 1건 이상 수정 | Agent+Human | ☐ |
| 25 | 프로덕션 또는 공개 테스트 전환 | Human | ☐ 개인계정: 비공개 테스트 12명×14일 + 계좌 인증 필요 |

---

## 추가 출시 블로커 (2026-07-26 점검)

| 항목 | 상태 |
|------|------|
| 결제 프로필 · 은행 계좌 `•••• 5079` 인증 | ☐ 지급 보류 (세금 정보는 승인됨) |
| 프로덕션 액세스 · 비공개 테스트 12명×14일 | ☐ 그룹 준비 중 · 내부 테스트와 별개 |

---

## Human 콘솔 실행 순서 (Agent 불가)

1. GitHub → Pages → `main` / `/docs` (이미면 스킵)
2. Play Console에 privacy URL 붙여넣기
3. Play 구독 상품 활성화 + RevenueCat 매핑(`pro`)
4. `REVENUECAT_ANDROID_KEY`로 릴리스 빌드 후 Paywall E2E
5. AAB 내부 테스트 업로드·테스터 초대

---

## 1-star 방지 P0 (이것만 안 하면 리뷰 깨짐)

1. **관계망 틀림** → 태그 수동 수정 (앱 내)
2. **데이터 날아감** → JSON 백업/복원
3. **Pro 사기** → 실결제 E2E 검증
4. **AI 기대 과장** → 온보딩·검색 배너 (무료/Pro 구분)
5. **크래시** → QA 체크리스트 + Crashlytics

---

## 출시 후 2주

- Crashlytics 일일 확인
- 1-star 리뷰 키워드: 그래프 / 결제 / 백업 / 위치
- 엔티티 오류 리포트 → lexicon·테스트 추가

## 1~2개월

- 회상·관계망 코치마크 개선
- 기억 100건+ 실사용자 그래프 UX
- Wrapped·스토리 (입소문)

## 장기

- iOS TestFlight
- 그래프 NL 질의
- 엔티티 수정 + AI 제안 하이브리드
