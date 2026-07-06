# 모담넷(MemoryOS) 상용화 종합 가이드 — TOTAL

**대상:** 운영자(개발자) · **갱신:** 2026-07-06  
**앱 완성도:** `kAppCompletionPercent = 95` (배포 가능 하한)  
**한 줄 요약:** 무료=기기·로컬 관계망 · Pro=AI·클라우드·복합 검색 (Google Play 구독)

---

## 목차

1. [이 문서를 어떻게 쓰나](#1-이-문서를-어떻게-나)
2. [무료 vs Pro — 확실한 경계](#2-무료-vs-pro--확실한-경계)
3. [관계망 AI(하이브리드) — 언제 켜지나](#3-관계망-ai하이브리드--언제-켜지나)
4. [SaaS란 무엇이고, 돈은 어떻게 들어오나](#4-saas란-무엇이고-돈은-어떻게-들어오나)
5. [월 요금은 얼마로 할까 (권장)](#5-월-요금은-얼마로-할까-권장)
6. [AI를 아주 많이 쓰면 어떻게 하나 (쿼터·공정 사용)](#6-ai를-아주-많이-쓰면-어떻게-하나-쿼터공정-사용)
7. [구독료 입금 경로 (당신 계좌까지)](#7-구독료-입금-경로-당신-계좌까지)
8. [영수증·세금·사업자](#8-영수증세금사업자)
9. [Google Play 등록 — 필요한 모든 것](#9-google-play-등록--필요한-모든-것)
10. [모담넷 홈페이지 — 어디에 무엇을](#10-모담넷-홈페이지--어디에-무엇을)
11. [95% 완성 기준 & 배포 전 체크](#11-95-완성-기준--배포-전-체크)
12. [문서 인덱스](#12-문서-인덱스)
13. [운영자가 할 일 vs 이미 구현된 것](#13-운영자가-할-일-vs-이미-구현된-것)

---

## 1. 이 문서를 어떻게 쓰나

| 상황 | 읽을 문서 |
|------|-----------|
| **처음 상용화** | 이 파일(TOTAL.md) 전체 → [SOFT_LAUNCH_7DAY.md](SOFT_LAUNCH_7DAY.md) |
| **Play 등록 문구·스크린샷** | [STORE_READINESS.md](STORE_READINESS.md) |
| **RevenueCat·Supabase 연동** | [SAAS_SETUP.md](SAAS_SETUP.md) |
| **실기기 QA** | [QA_CHECKLIST.md](QA_CHECKLIST.md) |
| **배포·SQL** | [DEPLOY.md](../DEPLOY.md) |

---

## 2. 무료 vs Pro — 확실한 경계

### 무료 (게스트 · 프라이버시 · 로그인 없이도 가능)

| 기능 | 설명 |
|------|------|
| 음성·텍스트·사진 저장 | 기기 `SharedPreferences` + 로컬 DB |
| **로컬 관계망** | 사람·장소·키워드 규칙으로 즉시 그래프 구성 |
| **키워드 검색** | `searchLocalMemories` — 인터넷·AI 없음 |
| 장소 회상 알림 | GPS + 백그라운드 워커 |
| 회상 타임라인 | 월별 그리드·상세 |
| JSON 백업/복원 | 설정 → 기억 백업 |
| 관계 태그 수동 수정 | 상세 → 관계 태그 편집 |
| 관계망 데이터 정리 | 빈 메모·캐시 정리 |

**UI 표시:** 검색 시 `로컬 키워드·관계망 검색 결과` 배너 · 설정 플랜 카드 「무료」

### Pro (월/연 구독 + 로그인 + 프라이버시 OFF 시 클라우드)

| 기능 | 설명 |
|------|------|
| **의미 검색·AI 답변** | 대화형 검색, 복합 질의 |
| **클라우드 동기화** | Supabase `memories` 테이블 |
| **관계 인사이트** | 사람·장소 빈도·감정 |
| **Graph AI 조각** | 저장 후 AI가 허브·위성 보조 |
| **관계망 AI(하이브리드)** | 설정 스위치 ON 시 백그라운드 분석 |
| 사진 AI·Vision OCR | 하이브리드/AI 전용 OCR |
| 올해의 기억·기념일 | Pro SaaS 대시보드 |
| 테마 허브 | 관계 포커스 뷰 |

**중요:** 관계망 **골격**은 Pro 없이도 동작합니다. Pro는 **AI 보조·클라우드·고급 검색**입니다.

코드 게이트: `lib/core/app_maturity.dart` — 완성도 ≥90% 시 `requiresProCloudForCloudFeatures` 활성.

---

## 3. 관계망 AI(하이브리드) — 언제 켜지나

### 활성화 조건 (네 가지 모두)

1. **MemoryOS Pro** 구독 (`entitlement: pro`, RevenueCat)
2. **로그인** (Supabase Auth, 게스트 아님)
3. **프라이버시 모드 OFF** (클라우드·AI 허용)
4. **설정 → 관계망 AI(하이브리드) 스위치 ON**

`graphAiLocked` 계산: `settings_screen.dart` · `settings_plan_cards.dart`

### 켜진 뒤 앱에서 보이는 것

| 영역 | 동작 |
|------|------|
| 저장 직후 | 백그라운드 `graph_ai_orchestrator` — 관계 조각 생성 |
| 관계망 탭 | 로컬 레이아웃 + AI 조각·허브 제목 보조 |
| 검색 | 그래프 DB 먼저 → AI가 답변 요약 (채팅 쿼터) |
| 노드 탭 대화 | `showGraphNodeAiSheet` — 노드 맥락 AI (쿼터) |
| Pro 클라우드 화면 | 채팅/임베딩/Vision 사용량 표시 |

### 꺼져 있을 때

로컬 규칙만: `buildEventGraphLayout`, `enrichMemoryGraphSemantics`, 엔티티 추출 — **무료와 동일**.

---

## 4. SaaS란 무엇이고, 돈은 어떻게 들어오나

**SaaS(Software as a Service)** = 앱을 한 번 사는 것이 아니라 **구독으로 서비스(AI·클라우드)를 파는 모델**.

모담넷 구조:

```
사용자
  → Google Play 결제 (카드/통신사 청구)
  → Google (중개·수수료 15~30%)
  → Play Console 정산
  → 운영자 등록 은행계좌 (원화 입금)

앱 (purchases_flutter)
  → RevenueCat (구독 상태·영수증 검증)
  → Webhook → Supabase user_subscriptions
  → AI 호출 시 consume_ai_quota
```

**사용자가 당신 개인 계좌로 직접 송금하지 않습니다.** 반드시 **Google Play 인앱 구독** 경로입니다.

---

## 5. 월 요금은 얼마로 할까 (권장)

한국 개인 생산성·AI 메모 앱 시장 참고 (2026):

| 상품 | 권장 가격 (KRW) | 비고 |
|------|-----------------|------|
| **월간** | **₩4,900 ~ ₩6,900** | 진입 장벽 낮게 |
| **연간** | 월 환산 **₩3,900 ~ ₩5,500** (약 20% 할인) | Play `memoryos_pro_annual` |

Play Console에서 **직접 가격 입력** → 각국 자동 환산.  
앱 내 가격은 `PaywallSheet`가 `pkg.storeProduct.priceString`으로 표시 (스토어가 결정).

**첫 소프트런치 제안:** 월 ₩5,900 · 연 ₩59,000 (실제 전환율 보며 조정)

---

## 6. AI를 아주 많이 쓰면 어떻게 하나 (쿼터·공정 사용)

서버·앱 동기화 한도 (`SubscriptionConfig` · `consume_ai_quota`):

| 종류 | Pro 월 한도 | 초과 시 |
|------|-------------|---------|
| 채팅·검색 AI | **500회** | `pro_quota_exceeded` 스낵바, 로컬 검색 fallback |
| 임베딩(의미 검색) | **300회** | 동일 |
| Vision(사진) | **100회** | 동일 |

**왜 한도가 있나:** OpenAI API 비용이 사용량에 비례. 무제한이면 월 ₩5,900 구독자가 수십만 원 API를 쓸 수 있음.

**운영 정책 (권장 문구 — 이용약관에 반영):**

- Pro는 **개인 일상 사용** 기준 월간 쿼터 제공
- 자동화·봇·상업적 대량 호출 금지
- 쿼터 초과 시 **다음 달 1일 리셋** (또는 연간 Pro 상향 패키지 검토)
- 악용 시 구독 제한 (RevenueCat / 수동 `user_subscriptions` 조정)

Pro SaaS 대시보드에서 **이번 달 사용량** 실시간 표시 (`pro_saas_dashboard.dart`).

---

## 7. 구독료 입금 경로 (당신 계좌까지)

### 단계별

1. **Google Play Console** 개발자 계정 등록 (등록비 **$25**, 1회)
2. **판매자 프로필** — 사업자 또는 개인, **정산 은행계좌** 등록 (한국 원화 가능)
3. **구독 상품** 생성: `memoryos_pro_monthly`, `memoryos_pro_annual`
4. **RevenueCat** 연동 → Play 서비스 계정 JSON 업로드
5. 사용자 구독 → Google이 결제 처리
6. **정산 주기:** 보통 **월 1회** (Google 정책·국가별 상이), 최소 지급액 이상일 때 계좌 입금
7. **수수료:** 첫 $1M 매출까지 **15%**, 이후 30% (Google Play 2024+ 정책 — 콘솔에서 확인)

### 당신이 확인하는 곳

- [Google Play Console](https://play.google.com/console) → **수익 창출** → 주문 관리 · 재무 보고서
- [RevenueCat Dashboard](https://app.revenuecat.com) → 구독·MRR·이탈

---

## 8. 영수증·세금·사업자

| 항목 | 누가 발급 | 설명 |
|------|-----------|------|
| **결제 영수증** | **Google Play** | 사용자 이메일 `Google Play 주문 영수증` |
| **앱 내 영수증** | Play → 구독 → 결제 내역 | 앱이 직접 세금계산서 발행 **안 함** |
| **개발자 매출 증빙** | Play Console 재무 보고서 | 부가세 신고·종합소득세 자료 |
| **한국 부가세** | Google이 원천징수·신고 (해외사업자 규정) | [Google Play 세금 정책](https://support.google.com/googleplay/android-developer/answer/6347809) 참고 |

**사업자 등록:** 연 매출 규모에 따라 **개인사업자** 등록 권장 (세무사 상담).  
앱 스토어 **판매자 명의**와 **세금 신고 명의**를 일치시키세요.

---

## 9. Google Play 등록 — 필요한 모든 것

### A. 계정·법적

- [ ] Google Play 개발자 계정 ($25)
- [ ] **개인정보처리방침 URL** (HTTPS) — [privacy.html](privacy.html) GitHub Pages
- [ ] **이용약관** — [terms.html](terms.html)
- [ ] 데이터 안전성 설문 (수집: 이메일, 위치, 사진, 기억 텍스트 등)
- [ ] 콘텐츠 등급 설문 (IARC)
- [ ] 타겟 연령 · 광고 여부 (보통 광고 없음)

### B. 스토어 리소스

| 항목 | 규격 | 내용 |
|------|------|------|
| 앱 이름 | 30자 | MemoryOS · 모담넷 |
| 짧은 설명 | 80자 | [STORE_READINESS.md](STORE_READINESS.md) |
| 전체 설명 | 4000자 | 무료/Pro 구분 명시 |
| 앱 아이콘 | 512×512 PNG | adaptive icon 원본 |
| 그래픽 이미지 | 1024×500 | 선택 |
| **스크린샷** | 2~8장, 16:9 또는 9:16 | `scripts/capture_store_screenshots.ps1` |
| 기능 그래픽 | 선택 | |

### C. 기술

- [ ] **AAB** 업로드: `.\scripts\build_bundle.ps1`
- [ ] 서명 키: `android/key.properties` + 백업
- [ ] `versionCode` / `versionName` 증가
- [ ] 구독 상품 ID = 코드와 일치 (`memoryos_pro_monthly` / `annual`)

### D. 결제 연결

상세 단계: **[PLAY_CONSOLE_SETUP.md](PLAY_CONSOLE_SETUP.md)**

```
Play Console 구독 생성
    ↓
RevenueCat Products + Entitlement `pro`
    ↓
secrets.local.json REVENUECAT_ANDROID_KEY
    ↓
Webhook → Supabase revenuecat-webhook
    ↓
앱 SubscriptionService.syncAfterLogin
```

### E. 테스트

- [ ] 내부 테스트 트랙 → 라이선스 테스터 계정
- [ ] 실결제 테스트 (소액) → 환불
- [ ] [QA_CHECKLIST.md](QA_CHECKLIST.md) 전 항목

---

## 10. 모담넷 홈페이지 — 어디에 무엇을

### 권장: GitHub Pages (무료·이미 `docs/` 있음)

```powershell
.\scripts\deploy_github_pages.ps1
# GitHub repo Settings → Pages → Branch: main, Folder: /docs
```

| URL | 파일 | 용도 |
|-----|------|------|
| `https://USER.github.io/personal_cognitiv/` | `docs/index.html` (만들 것) | 랜딩 |
| `.../privacy.html` | `docs/privacy.html` | **Play 필수** |
| `.../terms.html` | `docs/terms.html` | 이용약관 |
| `.../guide.html` | MODAMNET 가이드 요약 | 선택 |

### 랜딩에 넣을 내용

- 앱 소개 (무료 vs Pro 한 표)
- Play Store 배지 링크 (출시 후)
- 개인정보·문의 이메일
- theNext / 모담넷 브랜드

**자체 도메인 (선택):** `modamnet.com` → GitHub Pages CNAME 또는 Cloudflare.

---

## 11. 95% 완성 기준 & 배포 전 체크

| 영역 | 95% 기준 | 현재 |
|------|----------|------|
| 핵심 루프 | 저장→타임라인→검색→회상 무크래시 | ✅ |
| 관계망 신뢰 | 편집·태그·re-enrich·정리 | ✅ 코드 + QA 대부분 |
| 무료/Pro 경계 | 게이트·배너·설정 플랜 카드 | ✅ |
| SaaS | RevenueCat·쿼터·대시보드 | ✅ 코드 / Play E2E 운영자 |
| 법적 | 앱 내 약관·정책 | ✅ / URL 공개 운영자 |
| 테스트 | 281+ unit | ✅ |
| 스토어 | 스크린샷·AAB·구독 | ☐ 운영자 |

**배포 가능 조건:** 위 표에서 **Play E2E·정책 URL·내부 테스트 3일** 완료 시.

---

## 12. 문서 인덱스

| 파일 | 용도 |
|------|------|
| **TOTAL.md** | 이 문서 — SaaS·Play·홈페이지 종합 |
| [MODAMNET_INDEX.md](MODAMNET_INDEX.md) | 전체 .md 색인 |
| [STORE_READINESS.md](STORE_READINESS.md) | 스토어 문구·스크린샷 |
| [SAAS_SETUP.md](SAAS_SETUP.md) | RevenueCat·Supabase 기술 설정 |
| [SOFT_LAUNCH_7DAY.md](SOFT_LAUNCH_7DAY.md) | 출시 7일 일정 |
| [QA_CHECKLIST.md](QA_CHECKLIST.md) | 실기기 QA |
| [MODAMNET_USER_GUIDE.md](MODAMNET_USER_GUIDE.md) | 사용자 가이드 원문 |
| [COMMERCIALIZATION_90_SPRINT.md](COMMERCIALIZATION_90_SPRINT.md) | 90% 스프린트 이력 |
| [DEPLOY.md](../DEPLOY.md) | Supabase·빌드 |
| [GITHUB_PAGES.md](GITHUB_PAGES.md) | Pages 배포 |

---

## 13. 운영자가 할 일 vs 이미 구현된 것

### 운영자(당신)가 반드시 할 일

1. Play 개발자 계정 + **정산 계좌** 연결
2. 구독 상품 가격 설정 (월/연)
3. RevenueCat + Supabase webhook 프로덕션 키
4. `privacy.html` / `terms.html` **공개 URL** → Play Console 입력
5. 내부 테스트 → 실결제 1회 → QA 체크리스트 잔여 3건
6. (권장) 사업자 등록·세무 상담

### 코드에 이미 구현됨

- Pro Paywall · 구매 복원 · entitlement
- AI 월 쿼터 · 초과 메시지
- Pro SaaS 대시보드 (동기화·Wrapped·쿼터)
- 무료 로컬 검색 fallback 배너
- 설정 플랜 비교 카드 · Graph AI 상태 카드
- JSON 백업/복원 · 관계 태그 수동 수정
- Crashlytics · 281+ tests

---

*문의·수정: 저장소 `docs/` PR 또는 이슈.*
