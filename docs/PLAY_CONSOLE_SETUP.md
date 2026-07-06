# Google Play Console — 구독·정산·출시 설정 (단계별)

**앱 ID:** `com.theNext.personal_cognitive`  
**구독 상품 ID (코드와 반드시 일치):** `memoryos_pro_monthly`, `memoryos_pro_annual`  
**RevenueCat Entitlement:** `pro`  
**종합 가이드:** [TOTAL.md](TOTAL.md) · [SAAS_SETUP.md](SAAS_SETUP.md)

---

## 0. 사전 준비 체크리스트

| # | 항목 | 상태 |
|---|------|------|
| 1 | Google Play 개발자 계정 ($25, 1회) | ☐ |
| 2 | 릴리스 AAB/APK 서명 (`android/key.properties`) | ☐ |
| 3 | 개인정보 URL (HTTPS) | `https://sungkuk-lim.github.io/personal_cognitiv/privacy.html` |
| 4 | 이용약관 URL | `https://sungkuk-lim.github.io/personal_cognitiv/terms.html` |
| 5 | GitHub Pages 활성화 | [GITHUB_PAGES.md](GITHUB_PAGES.md) |
| 6 | RevenueCat 프로젝트 + Android SDK 키 | `secrets.local.json` |

---

## 1. 개발자 계정·판매자 프로필

1. [Google Play Console](https://play.google.com/console) 로그인
2. **설정 → 개발자 계정** — 등록비 결제 ($25)
3. **설정 → 결제 프로필** (판매자 프로필)
   - **사업자 유형:** 개인 또는 법인
   - **한국 은행 계좌** 등록 (정산 입금용)
   - **세금 정보** (W-8BEN / 한국 거주자 정보)
4. **정산 주기:** 월 1회 (최소 지급액 ₩100,000 — 콘솔에서 확인)

> 사용자가 당신 계좌로 직접 송금하지 않습니다. Google Play가 결제·정산합니다.

---

## 2. 앱 생성

1. **모든 앱 → 앱 만들기**
2. **앱 이름:** MemoryOS (모담넷)
3. **기본 언어:** 한국어
4. **앱 / 게임:** 앱
5. **무료 / 유료:** 무료 (인앱 구독으로 수익)

### 앱 서명

- **Play App Signing** 사용 권장 (Google이 배포 키 관리)
- 업로드 키: `scripts/create_keystore.ps1`로 생성한 keystore

---

## 3. 구독 상품 등록 (필수)

**경로:** 앱 선택 → **수익 창출 → 구독 → 구독 만들기**

### 3-1. 기본 구독 그룹

- **구독 그룹 ID:** `memoryos_pro` (임의, 하나만 있으면 됨)
- 같은 그룹 내 월간·연간은 **상호 배타** (한 번에 하나만 구독)

### 3-2. 월간 구독

| 필드 | 값 |
|------|-----|
| **제품 ID** | `memoryos_pro_monthly` |
| **이름** | MemoryOS Pro (월간) |
| **설명** | AI 검색·클라우드 동기화·관계망 AI·관계 인사이트 |
| **청구 기간** | 1개월 |
| **가격** | ₩5,900 (소프트런치 제안, [TOTAL.md](TOTAL.md) §5) |
| **무료 체험** | 선택 (예: 7일) |
| **유예 기간** | 3일 권장 |

### 3-3. 연간 구독

| 필드 | 값 |
|------|-----|
| **제품 ID** | `memoryos_pro_annual` |
| **이름** | MemoryOS Pro (연간) |
| **청구 기간** | 1년 |
| **가격** | ₩59,000 (월 환산 약 17% 할인) |

### 3-4. 활성화

- 구독 상태: **활성**
- **국가/지역:** 대한민국 우선, 필요 시 전 세계

---

## 4. RevenueCat 연동

### 4-1. Play ↔ RevenueCat 서비스 계정

1. Play Console → **설정 → API 액세스**
2. **Google Cloud 프로젝트** 연결
3. **서비스 계정** 생성 → **재무 데이터 보기** 권한
4. JSON 키 다운로드
5. RevenueCat → Project → **Google Play** → JSON 업로드

### 4-2. RevenueCat 상품 매핑

| RevenueCat Product | Play Product ID |
|--------------------|-----------------|
| monthly | `memoryos_pro_monthly` |
| annual | `memoryos_pro_annual` |

**Entitlement:** `pro` → 위 두 상품 연결

### 4-3. 앱 SDK 키

RevenueCat → Apps → Android → **Public API Key** (`goog_...`)

`secrets.local.json`:

```json
{
  "REVENUECAT_ANDROID_KEY": "goog_xxxxxxxx"
}
```

### 4-4. Webhook → Supabase

- URL: `https://YOUR_PROJECT.supabase.co/functions/v1/revenuecat-webhook`
- Authorization: `Bearer YOUR_WEBHOOK_SECRET`
- Supabase secret: `REVENUECAT_WEBHOOK_SECRET`

---

## 5. 스토어 등록 정보

**경로:** **스토어 등록 → 기본 스토어 등록정보**

| 항목 | 내용 |
|------|------|
| 앱 이름 | MemoryOS · 모담넷 |
| 짧은 설명 | [STORE_READINESS.md](STORE_READINESS.md) |
| 전체 설명 | 무료=로컬·Pro=AI 명시 |
| 앱 아이콘 | 512×512 PNG |
| 스크린샷 | 5장 (`scripts/capture_store_screenshots.ps1`) |
| **개인정보처리방침 URL** | GitHub Pages privacy.html |
| **이메일** | 고객 문의용 |

---

## 6. 정책·데이터 안전성

### 데이터 안전성 설문

| 데이터 | 수집 | 공유 | 목적 |
|--------|------|------|------|
| 이메일 | 예 (로그인 시) | 아니오 | 계정 |
| 위치 | 예 (선택) | 아니오 | 장소 회상 |
| 사진 | 예 | 아니오 | 기억 저장 |
| 텍스트(기억) | 예 | 아니오 | 앱 기능 |

- **암호화:** 전송 중 암호화 예
- **삭제 요청:** 앱 내 계정 삭제 지원

### 콘텐츠 등급

- IARC 설문 → 보통 **전체이용가** 또는 **12+**

---

## 7. 테스트·출시 트랙

### 내부 테스트 (권장 순서)

1. **테스트 → 내부 테스트** 트랙 생성
2. AAB 업로드: `.\scripts\build_bundle.ps1`
3. **라이선스 테스터** 추가 (설정 → 라이선스 테스트)
4. 실기기: Paywall → 테스트 카드 결제 → Pro 활성 확인

### 검증 항목

- [ ] `memoryos_pro_monthly` Paywall 가격 표시
- [ ] 결제 후 `hasProEntitlementProvider` = true
- [ ] AI 검색·Graph AI 스위치 해제 가능
- [ ] 구독 취소 후 만료 시 무료로 복귀
- [ ] [QA_CHECKLIST.md](QA_CHECKLIST.md)

### 프로덕션

- 내부 → **비공개 테스트** (선택) → **프로덕션**
- **국가:** 대한민국 먼저

---

## 8. 정산·입금 흐름

```
사용자 Play 결제
    → Google 수수료 15~30% 차감
    → Play Console 재무 보고서
    → 등록 은행계좌 입금 (월 1회)
```

**확인 위치:**

- Play Console → **수익 창출 → 재무 보고서**
- RevenueCat → **Charts** (MRR, 이탈)

**영수증:** 사용자에게는 **Google Play 주문 영수증** (앱이 세금계산서 발행 안 함)

---

## 9. 앱 빌드 업로드

```powershell
cd d:\android\personal_cognitiv
.\scripts\build_bundle.ps1
# → build\app\outputs\bundle\release\app-release.aab
```

Play Console → **출시 → 프로덕션(또는 내부 테스트)** → 새 버전 만들기 → AAB 업로드

---

## 10. 출시 후 모니터링

| 도구 | URL |
|------|-----|
| Play Console | 앱 통계·비정상 종료·리뷰 |
| Firebase Crashlytics | [FIREBASE_SETUP.md](FIREBASE_SETUP.md) |
| RevenueCat | 구독·환불 |
| Supabase | `user_subscriptions`, AI 쿼터 |

---

## 빠른 참조 — 코드 상수

```dart
// lib/core/subscription_config.dart
productMonthly = 'memoryos_pro_monthly'
productAnnual  = 'memoryos_pro_annual'
entitlementPro = 'pro'
```

Play Console 제품 ID가 **한 글자라도 다르면** 결제가 동작하지 않습니다.
