# Play Store 등록 자료 (MemoryOS)

## 앱 이름
- 한국어: **MemoryOS · 모담넷**
- 영어: **MemoryOS**

## 짧은 설명 (80자 이내)
```
AI가 음성·사진 기억을 자동 정리하고, 장소·관계망으로 다시 떠올려 주는 개인 메모리 앱
```

## 전체 설명

```
MemoryOS는 폴더와 태그 없이도 기억을 쌓고, 필요할 때 자연어로 찾을 수 있는 개인 인지 보조 앱입니다.

■ 핵심 기능
• 음성 저장: 말하면 AI가 분류·요약해 저장
• 사진·OCR: 카메라로 촬영한 글자·장면을 기억으로 보관
• 대화형 검색: "지난달 제주도 뭐 했지?"처럼 질문
• 관계망: 사람·장소·키워드 연결을 시각화
• 회상 타임라인: 월별로 기억을 다시 보기
• 선제적 소환: 과거 방문 장소에서 잊은 기억 알림

■ 프라이버시
• 게스트·프라이버시 모드: 기기에만 저장 가능
• 클라우드 동기화는 로그인 후 선택 사용

■ 요금
앱 무료 · OpenAI/클라우드 사용량은 본인 계정 기준

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

## 완성도 (2025-06 기준)

| 항목 | 상태 |
|------|------|
| 핵심 기능 | ~93% |
| UX·안정성 | ~88% |
| Firebase Crashlytics | **연동 완료** |
| 스토어 준비 | ~82% |
| **스토어 등록 권장** | **95% 도달 시** |

남은 작업: Crashlytics 콘솔 활성화, 릴리스 서명·실기기 QA, 정책 URL 공개 호스팅, 스크린샷 5장
