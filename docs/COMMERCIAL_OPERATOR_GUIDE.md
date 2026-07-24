# 모담넷(MemoryOS) 상용 운영자 가이드

개발자가 **따라하기만** 하면 되는 체크리스트입니다.  
앱 코드는 이미 SaaS 골격·Paywall·쿼터·웹훅·계정삭제를 갖추고 있습니다.

---

## 0. 한눈에 — 지금 vs 해야 할 일

| 영역 | 이미 됨 (코드) | 당신이 할 일 (콘솔) |
|------|----------------|---------------------|
| 이메일 로그인 | Firebase+Supabase 브리지 | Firebase Auth 이메일 사용 설정 |
| 게스트 / 지문·패턴 | 로그인 3경로 UI | 없음 |
| 클라우드 DB | Supabase 마이그레이션 | `006_sync_own_pro_entitlement.sql` 적용 |
| AI 프록시 | Edge `openai-proxy` | Supabase secrets에 OpenAI 키 |
| 구독 UI | Paywall·복원·새로고침 | Play 상품 + RevenueCat 키 |
| Pro 자동 반영 | RC→로컬→`sync_own_pro`→웹훅 | RC 웹훅 URL 등록 |
| 개인정보/약관 | 앱 내 MD + GitHub Pages | Pages URL을 Play에 입력 |
| 스토어 에셋 | `store_screenshots/` | Play Console에 업로드 |

**「구독 상품 연동 준비중」이 뜨는 이유:**  
`secrets.local.json`에 `REVENUECAT_ANDROID_KEY`가 없거나, Play/RevenueCat에 상품·Offering이 비어 있음.

---

## 1. 로그인 3가지 (앱 UX)

1. **이메일 계정** — 클라우드·Pro·AI  
2. **게스트** — 기기 전용 (구독/AI 클라우드 없음)  
3. **지문·패턴** — 기기 보안으로 로컬 모드 시작  

Pro를 팔려면 사용자를 **이메일 로그인**으로 유도하세요.

---

## 2. AI 쓰는 것 / 안 쓰는 것

### Pro + 로그인 + (프라이버시 OFF) 일 때 AI 사용
- 의미 검색·AI 답변  
- 관계망 AI 보조  
- 사진 Vision 분석 (엔진이 Vision/Hybrid일 때)  
- 임베딩·클라우드 동기화  

### 무료·게스트·프라이버시 ON — AI 없음 (로컬만)
- 타임라인 저장·편집  
- 관계망 골격(규칙 기반)  
- 키워드 검색  
- 기기 OCR (ML Kit)  
- 장소 회상 알림·Replay·홈 위젯  

---

## 3. 구독료 — 얼마를 받을지 (권장 구조)

Play Console에 **직접 가격을 등록**합니다. 앱은 스토어 가격 문자열을 표시합니다.

| 상품 ID (코드와 동일) | 권장가 | 비고 |
|----------------------|--------|------|
| `memoryos_pro_monthly` | **₩5,900** | 소프트런치 |
| `memoryos_pro_annual` | **₩59,000** | 약 17% 할인 |

### 헤비 유저·원가 방어 (코드 적용 · 2026-07 재검증)

월간 상한 (서버 `consume_ai_quota` = 클라 `SubscriptionConfig`):

| 종류 | 월 한도 |
|------|---------|
| 채팅/완성 | **500** |
| 임베딩 | **300** |
| Vision | **100** |

**방어 계층**
1. **무료·게스트·프라이버시** → OpenAI **0원** (클라우드 AI 차단)
2. **Pro만** Edge `openai-proxy` → `consume_ai_quota` 통과 후 OpenAI
3. **월 한도 초과** → 429, 그달 AI만 차단 · 로컬 기억·관계망 골격은 유지
4. **릴리스 APK**에 `OPENAI_API_KEY` 미주입 (`build_release_secrets.ps1`) — 클라 직접 호출 불가
5. **Edge 실패 시 직접 OpenAI 폴백 금지** (`AiService` fail-closed) — 쿼터 우회 구멍 차단
6. **절감**: 기기 STT(1차) · OCR 저비용/하이브리드 · 사진 첫 장만 Vision · Graph AI debounce

**한계(완전 0원 보장 아님)**
- 호출 **횟수** 한도이며 토큰/$ 상한은 없음 (고품질 Vision·긴 채팅도 1회로 카운트)
- Graph AI ON이면 저장마다 chat 1~2회 → 한도 내에서도 원가 발생
- 헤비 유저가 많으면 쿼터를 400/250/80으로 낮추기 (SQL+`SubscriptionConfig` 동시 수정)

### Pro가 “자동 반영”되는 실제 흐름
1. 사용자가 Paywall에서 구매 (RevenueCat SDK)  
2. 앱이 **즉시** Pro UI 반영  
3. 앱이 Supabase `sync_own_pro_entitlement` 호출 (웹훅 지연 대비) — **migration 006 필요**  
4. RevenueCat 웹훅이 `upsert_user_subscription` 재확인  
5. 설정 → **구독 상태 새로고침**으로 수동 재확인 가능  

---

## 4. 당신만 하면 되는 최소 작업 (순서대로)

### A. Supabase
```bash
# 프로젝트 루트에서
supabase db push
# 또는 SQL Editor에 migrations/006_sync_own_pro_entitlement.sql 붙여넣기 실행
```
Edge Function `openai-proxy`, `revenuecat-webhook` 배포 + secrets:
- `OPENAI_API_KEY`
- `REVENUECAT_WEBHOOK_SECRET`
- `SUPABASE_SERVICE_ROLE_KEY`

### B. Google Play (수익)
1. 개발자 계정 $25 + **결제 프로필**(은행·세금)  
2. 앱 만들기 · AAB 업로드 (`.\scripts\build_bundle.ps1`)  
3. **구독** 생성: ID를 코드와 **一字一句** 동일하게  
4. 개인정보·약관 URL (HTTPS) 입력  

상세: [PLAY_CONSOLE_SETUP.md](PLAY_CONSOLE_SETUP.md)

### C. RevenueCat (필수 — 지금 키 없음)
1. Android 앱 연결 + Play 서비스계정 JSON  
2. Product `memoryos_pro_monthly` / `annual` → Entitlement **`pro`**  
3. Offering **`current`**에 패키지 추가  
4. Public SDK key (`goog_...`) → `secrets.local.json`:
```json
"REVENUECAT_ANDROID_KEY": "goog_xxxx"
```
5. Webhook → Supabase Function URL  
6. `.\scripts\build_release.ps1` 로 다시 빌드·설치  

키가 들어가면 「연동 준비중」이 사라지고 **구매 버튼**이 보입니다.

### D. Firebase
Console → Authentication → **이메일/비밀번호** 사용 설정

---

## 5. Google Play에 올릴 자료

| 자료 | 위치 / 내용 |
|------|-------------|
| AAB | `build/app/outputs/bundle/release/app-release.aab` |
| 스크린샷 | `store_screenshots/01_*.png` ~ `05_*.png` |
| 아이콘 | Play용 512px (런처에서 추출) |
| Feature Graphic | 1024×500 (별도 제작) |
| 짧은 설명 | STORE_READINESS.md |
| 개인정보 URL | `AppUrls.privacyPolicy` |
| 약관 URL | `AppUrls.termsOfService` |
| 콘텐츠 등급 | 설문 응답 |
| 타겟 API | 현재 프로젝트 compileSdk |

리스팅 카피: [STORE_READINESS.md](STORE_READINESS.md)

### 법·저작권 (분쟁 예방)
- UI는 **시스템 폰트** (별도 상용 폰트 미번들)  
- PDF 가이드 Noto: OFL — `scripts/setup_guide_font.ps1`  
- 계정 삭제: 설정 → 프라이버시·계정 (privacy.md 반영됨)  
- Crashlytics: 크래시만 수집, 마케팅 추적 아님  
- OpenAI 키는 **클라이언트에 넣지 말 것** (Edge만)

---

## 6. 앱 사용법 (사용자용 요약)

1. **기억 저장** — 음성/사진/텍스트  
2. **타임라인** — 날짜순 회상  
3. **검색** — 키워드(무료) / AI(Pro)  
4. **관계망** — 사람·장소 연결 (AI는 Pro)  
5. **설정** — 도움말 → 구독 → 잠금 → 프라이버시 순  

---

## 7. 검증 체크 (출시 직전)

- [ ] 이메일 가입·로그인  
- [ ] 게스트·지문 경로  
- [ ] Paywall에 가격 버튼 표시 (연동 준비중 아님)  
- [ ] 테스트 카드로 구매 → Pro 배지·AI 동작  
- [ ] 설정 → 구독 상태 새로고침  
- [ ] 쿼터 초과 메시지  
- [ ] 계정 삭제  
- [ ] privacy/terms URL Play와 앱 일치  

---

## 8. 관련 문서

- [PLAY_CONSOLE_SETUP.md](PLAY_CONSOLE_SETUP.md) — Play·RC 상세  
- [SAAS_SETUP.md](SAAS_SETUP.md) — Supabase SaaS  
- [PRO_TEST_GRANT.md](PRO_TEST_GRANT.md) — 수동 Pro 부여 (QA)  
- [STORE_READINESS.md](STORE_READINESS.md) — 스토어 문구  
