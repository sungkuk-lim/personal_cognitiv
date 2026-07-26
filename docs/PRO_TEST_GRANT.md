# Supabase SQL Editor — 테스트용 Pro 30일 부여

**전제:** 앱에서 이메일 로그인 1회 완료

**빠른 실행 (Windows):** 프로젝트 루트에서

```powershell
.\scripts\open_pro_grant.ps1
# UID 알고 있으면:
.\scripts\open_pro_grant.ps1 -UserUuid "your-uuid-here"
```

브라우저에서 Authentication → Users 와 SQL Editor 가 열립니다.

## 1) 사용자 UUID 확인

Supabase Dashboard → **Authentication → Users** → 본인 이메일 → **User UID** 복사

또는 SQL Editor:

```sql
SELECT id, email, created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;
```

## 2) Pro 부여 (30일)

`YOUR_USER_UUID` 를 위 UID로 바꾼 뒤 실행:

```sql
SELECT upsert_user_subscription(
  'YOUR_USER_UUID'::uuid,
  'pro',
  'active',
  now() + interval '30 days',
  'manual_test',
  'memoryos_pro_monthly'
);
```

## 3) 확인

```sql
SELECT * FROM user_subscriptions WHERE user_id = 'YOUR_USER_UUID'::uuid;
```

## 4) 앱에서

1. secrets 포함 APK 설치
2. **게스트 OFF · 프라이버시 OFF** 로그인
3. 설정 → **구독 상태 새로고침** (또는 Paywall 내 새로고침)
4. 설정 → **관계망 AI(하이브리드)** 스위치 ON

## QA APK (SQL 없이 Pro 테스트)

RevenueCat 키가 없거나 SQL 실행 전에 UI만 검증할 때:

```powershell
.\scripts\build_release_secrets.ps1 -ProBypass
```

`DEV_PRO_BYPASS=true` 가 포함됩니다. **Play 스토어 업로드 금지** — 내부 QA 전용입니다.

## Pro 해제 (테스트 후)

```sql
SELECT upsert_user_subscription(
  'YOUR_USER_UUID'::uuid,
  'free',
  'canceled',
  NULL,
  'manual_test',
  NULL
);
```
