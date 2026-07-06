# Supabase SQL Editor — 테스트용 Pro 30일 부여

**전제:** 앱에서 이메일 로그인 1회 완료

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
3. Paywall → **구독 상태 새로고침** (RevenueCat + Supabase)
4. 설정 → **관계망 AI(하이브리드)** 스위치 ON

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
