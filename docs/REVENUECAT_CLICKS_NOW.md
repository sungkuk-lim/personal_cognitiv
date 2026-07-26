# RevenueCat · Play — Paywall E2E

**상태 (2026-07-24 21:40)**
- [x] 폰에 Play 설치본 **1.0.2 (3)** 확인
- [x] RC Offering `default` 패키지 비어 있던 문제 수정 (월/연 product 다시 연결)
- [x] 앱 재실행 → Paywall에 월/연 가격 표시 확인
- [x] 테스트 구매 성공 → **Pro 활성화** 확인 (2026-07-24)

원인: RevenueCat Offering에 상품이 대시보드/API에는 보였지만, SDK용 offerings 응답의 `packages`가 비어 있었음.  
새 패키지에 Play 상품을 다시 attach 한 뒤 `default` offerings에 `memoryos_pro_monthly` / `annual`이 내려오기 시작함.


AAB 파일:
```
d:\android\personal_cognitiv\build\app\outputs\bundle\release\app-release.aab
```

내부 테스트 링크:
```
https://play.google.com/apps/internaltest/4701573125286475466
```

---

## 1. AAB 업로드·출시 (콘솔 · 약 5분)

1. [Play Console](https://play.google.com/console) → **MemoryOS**
2. **테스트 → 내부 테스트 → 새 버전 만들기**
3. **앱 번들 업로드** → 위 `.aab` 선택
4. 출시 이름: `1.0.2 (3)`
5. **출시 검토 / 출시 시작** (또는 초안 저장 후 출시)

> 서비스 계정 `revenuecat-play@...` 에 **「테스트 트랙으로 앱 출시」** 권한을 주면  
> 이후 `python scripts/upload_play_internal_aab.py ...` 로 자동 출시 가능.

---

## 2. 테스터 + 라이선스 테스터

1. 내부 테스트 → **테스터** 탭 → 이메일 목록에 **본인 Gmail** 추가·저장  
2. **설정 → 라이선스 테스트** → 같은 Gmail 추가 (테스트 결제 무료)

---

## 3. 폰 설치·Paywall

1. 폰 브라우저/Play에서 내부 테스트 링크 열기 → **수락 → 다운로드/업데이트**
2. 앱 실행 → **로그인**
3. 설정 → **MemoryOS Pro** → 월/연 가격 표시 확인 → 구매
4. Pro 활성되면 성공

가격이 안 보이면: Play 설치본인지, 테스터·라이선스 이메일, 앱 강제 종료 후 재실행.

---

## (참고) USB 설치 불가

Play 서명 앱과 로컬 keystore가 달라 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.  
구독도 **Play 설치본**에서만 안정적으로 동작합니다.
