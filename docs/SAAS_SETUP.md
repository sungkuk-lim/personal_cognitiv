# MemoryOS SaaS (Pro 구독) 설정 가이드

MemoryOS Pro는 **Freemium + 월/연 구독** 구조입니다.

| 티어 | 기능 |
|------|------|
| **무료** | 게스트·프라이버시 모드 — 기기 저장, 로컬 검색, 회상 알림 |
| **Pro** | 클라우드 동기화, AI 분류·의미 검색, 사진 Vision, 관계망 AI |

AI 월간 한도 (Pro): 채팅 500 · 임베딩 300 · Vision 100 (서버 `consume_ai_quota`와 동일)

---

## 1. Supabase 마이그레이션

```powershell
cd d:\android\personal_cognitiv
supabase db push
# 또는 SQL Editor에서 supabase/migrations/004_subscriptions.sql 실행
```

Edge Function 재배포:

```powershell
supabase functions deploy openai-proxy
supabase functions deploy revenuecat-webhook
```

---

## 2. RevenueCat + Google Play

1. [RevenueCat](https://www.revenuecat.com) 프로젝트 생성
2. Google Play Console → **구독** 상품 등록:
   - `memoryos_pro_monthly`
   - `memoryos_pro_annual`
3. RevenueCat → Entitlement **`pro`** 생성 → 위 상품 연결
4. RevenueCat → Android 앱 → **공개 SDK 키** 복사
5. Webhook URL: `https://YOUR_PROJECT.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization: `Bearer YOUR_WEBHOOK_SECRET`
   - Supabase Secret: `REVENUECAT_WEBHOOK_SECRET`

---

## 3. secrets.local.json

```json
{
  "SUPABASE_URL": "...",
  "SUPABASE_ANON_KEY": "...",
  "REVENUECAT_ANDROID_KEY": "goog_..."
}
```

빌드:

```powershell
.\scripts\build_release.ps1
```

개발 중 Pro 우회 (로컬 QA만):

```powershell
flutter run --dart-define=DEV_PRO_BYPASS=true
```

---

## 4. 수동 Pro 부여 (테스트)

Supabase SQL Editor:

```sql
SELECT upsert_user_subscription(
  'USER_UUID'::uuid,
  'pro',
  'active',
  now() + interval '30 days',
  'manual',
  'memoryos_pro_monthly'
);
```

---

## 5. 아키텍처

```
앱 (purchases_flutter)
  → Google Play Billing
  → RevenueCat
  → webhook → Supabase user_subscriptions

AI 호출
  → openai-proxy Edge Function
  → consume_ai_quota RPC
  → OpenAI
```

---

## 6. 스토어 문구

Play Console **전체 설명**에 반영:

- 앱 무료 다운로드
- MemoryOS Pro: 클라우드·AI 기능 (월/연 구독)
- 무료: 기기 저장·로컬 검색

`docs/STORE_READINESS.md` 요금 섹션도 함께 수정하세요.
