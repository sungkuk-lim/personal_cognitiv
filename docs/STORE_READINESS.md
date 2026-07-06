# Play Store 등록 자료 (MemoryOS)

## 앱 이름
- 한국어: **MemoryOS · 모담넷**
- 영어: **MemoryOS**

## 짧은 설명 (80자 이내)
```
말한 기억을 로컬 관계망으로 즉시 정리하고, Pro에서 AI 검색·인사이트로 다시 떠올리는 개인 메모리 앱
```

## 전체 설명

```
MemoryOS(모담넷)는 폴더 없이 기억을 쌓고, 관계망으로 사람·장소·사건을 연결해 다시 찾는 개인 인지 보조 앱입니다.

■ 로컬 vs AI (핵심 구조)
• 무료·기기: 음성·사진 저장, 관계망 골격(허브·위성·관계선), 키워드 검색 — 즉시 기기에서 동작
• Pro·클라우드: 의미 검색·AI 답변, 관계 인사이트, 복합 질의, Graph AI 조각, 사진 AI 분석
• 관계망은 항상 로컬 규칙으로 먼저 구성되고, AI는 보조(Pro + 설정 ON 시)

■ 핵심 기능
• 음성 저장: 말하면 분류·요약해 저장
• 사진·OCR: 촬영한 글자·장면을 기억으로 보관
• 관계망: 사람·장소·키워드 연결을 시각화 (로컬 즉시)
• 대화형 검색(Pro): "지난달 제주도 뭐 했지?"처럼 질문
• 회상 타임라인: 월별로 기억을 다시 보기
• 선제적 소환: 과거 방문 장소에서 잊은 기억 알림

■ 프라이버시
• 게스트·프라이버시 모드: 기기에만 저장 가능
• 개인정보 처리방침·이용약관: 앱 내에서 확인
• 클라우드 동기화는 로그인 후 선택 사용

■ 요금
앱 무료 · MemoryOS Pro(월/연 구독): 클라우드·AI 검색·인사이트·Graph AI·사진 분석
무료: 기기 저장·로컬 관계망·키워드 검색·장소 회상 알림

개발: theNext
```

## 카테고리
- **생산성** 또는 **라이프스타일**

## 콘텐츠 등급
- 전체 이용가 (개인 메모·위치 알림)

## 스크린샷 체크리스트 (1080×1920 또는 1440×2560)

| # | 화면 | 캡처 내용 |
|---|------|-----------|
| 1 | 타임라인 | 기억 카드 2~3개 |
| 2 | 검색 | 대화형 검색 결과 |
| 3 | 관계망 | 노드 그래프 |
| 4 | 회상 | 월별 썸네일 |
| 5 | 설정 | 프라이버시·OCR 옵션 |

```powershell
# 에뮬레이터 또는 실기기에서
adb exec-out screencap -p > screenshot_01.png
```

## 개인정보 처리방침 URL

Play Console에 **공개 HTTPS URL** 필수.

### 방법 A: GitHub Pages (무료)
1. 저장소 Settings → Pages → Source: `main` / `/docs`
2. `docs/privacy.html` 배포 후 URL 예:
   `https://YOUR_USER.github.io/personal_cognitiv/privacy.html`

### 방법 B: Supabase Storage (이미 사용 중)
`docs/PRIVACY_POLICY.md`를 public bucket에 업로드 후 public URL 사용

현재 로컬 파일: [docs/PRIVACY_POLICY.md](PRIVACY_POLICY.md)  
웹용 HTML: [docs/privacy.html](privacy.html)

## 릴리스 빌드

```powershell
# 1. 키스토어 (최초 1회)
.\scripts\create_keystore.ps1
copy android\key.properties.example android\key.properties
# key.properties 값 입력

# 2. Firebase
.\scripts\setup_firebase.ps1

# 3. 릴리스 APK
.\scripts\build_release.ps1
```

출력: `build/app/outputs/flutter-apk/app-release.apk`

## 완성도 (2026-07 기준)

| 항목 | 상태 |
|------|------|
| 핵심 기능 | **~95%** |
| UX·안정성 | ~94% |
| 단위 테스트 | **281건+ 통과** |
| Firebase Crashlytics | **연동 완료** |
| 릴리스 APK 서명 | **완료** |
| 개인정보·이용약관 | **앱 내 뷰어** |
| Pro SaaS 대시보드 | **구현 완료** |
| 설정 플랜·Graph AI 안내 | **구현 완료** |
| 스토어 준비 | ~95% |
| **스토어 등록 권장** | **TOTAL.md·SOFT_LAUNCH 완료 후** |

종합 가이드: [TOTAL.md](TOTAL.md) · 문서 색인: [MODAMNET_INDEX.md](MODAMNET_INDEX.md)

남은 작업: [SOFT_LAUNCH_7DAY.md](SOFT_LAUNCH_7DAY.md) D-7~D-Day, Play 구독·정책 URL·스크린샷
