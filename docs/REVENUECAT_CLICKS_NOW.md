# RevenueCat · Play — 남은 클릭만 (에이전트가 JSON까지 생성함)

**상태 (자동 완료 · 2026-07-24 재확인)**
- [x] `REVENUECAT_ANDROID_KEY` (`goog_...`) → `secrets.local.json`
- [x] 서비스 계정 JSON → `secrets/revenuecat-play-sa.json`
- [x] Android Publisher API 활성화
- [x] RC Products: `memoryos_pro_monthly:monthly` / `memoryos_pro_annual:annual`
- [x] RC Entitlement `pro` + Offering `default`(current) + packages `$rc_monthly` / `$rc_annual`
- [ ] **Supabase 프로젝트 재활성화** (현재 `INACTIVE` — DNS 미응답) ← **구독 동기화·AI 쿼터 차단 중**
- [ ] SQL Editor: `006_sync_own_pro_entitlement.sql` 적용
- [ ] Edge `revenuecat-webhook` 배포 + RC 웹훅 URL 등록
- [ ] 내부 테스트 설치본에서 Paywall E2E

---

## 지금 당장 (1) Supabase 복구

1. https://supabase.com/dashboard → 프로젝트 `xfovfhhfarxmzsislbeb`
2. **Restore / Resume** (Paused·Inactive면 유휴 중지일 가능성)
3. 복구 후 REST URL이 다시 응답하는지 확인

복구 전엔 Pro AI·쿼터·`sync_own_pro_entitlement`가 **동작하지 않습니다.**  
(앱은 Edge 실패 시 OpenAI 직접 호출을 **하지 않음** → 원가는 막히지만 Pro AI도 멈춤)

---

## A. Play Console — 서비스 계정 권한 (필수)

1. 열린 [Play Console](https://play.google.com/console) → **사용자 및 권한** (Users and permissions)  
   또는 **설정 → API 액세스**
2. **새 사용자 초대** / Invite user  
   이메일 붙여넣기:
   ```
   revenuecat-play@memoryos-personal-cognitiv.iam.gserviceaccount.com
   ```
3. 권한 (앱 `MemoryOS` / `com.theNext.personal_cognitive`에):
   - **재무 데이터 보기** (View financial data)
   - **주문 및 구독 관리** (Manage orders and subscriptions) — 있으면 체크
   - 앱 정보 보기
4. 초대 저장 (서비스 계정은 이메일 수락 없음 — 바로 활성인 경우 많음)

> API 액세스 화면에 Cloud 프로젝트 연결이 뜨면  
> `memoryos-personal-cognitiv` 를 연결한 뒤 같은 계정이 목록에 보이면 위 권한만 주면 됩니다.

---

## B. RevenueCat — JSON 업로드 (필수)

1. RevenueCat → Apps → **MemoryOS (Modamnet) (Play Store)**
2. Explorer에 열린 폴더에서 `revenuecat-play-sa.json` 을  
   **Service Account Credentials JSON** 칸에 드래그
3. **Save**

---

## C. Play Console — 구독 상품 2개 (필수)

경로: 앱 → **수익 창출 → 구독 → 구독 만들기**

| 제품 ID (그대로) | 이름 | 기간 | 가격 |
|------------------|------|------|------|
| `memoryos_pro_monthly` | MemoryOS Pro (월간) | 1개월 | ₩5,900 |
| `memoryos_pro_annual` | MemoryOS Pro (연간) | 1년 | ₩59,000 |

- 구독 그룹: `memoryos_pro` (하나만)
- **활성화/게시**까지 완료

> 구독 메뉴가 안 보이면: 먼저 **내부 테스트**에 AAB/APK를 한 번 올린 뒤 다시 시도.

---

## D. RevenueCat — Entitlement · Offering (필수)

1. **Entitlements** → 없으면 생성 ID: `pro` (소문자 그대로)
2. **Products** → Play 상품 `memoryos_pro_monthly` / `memoryos_pro_annual` import 또는 동일 ID로 추가 → 둘 다 entitlement `pro`에 연결
3. **Offerings** → `default` 또는 `current` → 패키지에 월간·연간만 (lifetime 있으면 제거)
4. Offering을 **Current**로 설정

---

## E. 앱 다시 빌드 (키 반영)

```powershell
cd d:\android\personal_cognitiv
.\scripts\build_release.ps1
```

---

막히면 **화면 제목 + 버튼 이름**만 채팅에 보내세요.
