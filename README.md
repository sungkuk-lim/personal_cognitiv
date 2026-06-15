# MemoryOS (Personal Cognitiv)

개인 기억 앱 — 음성·사진·AI 검색·관계망·선제적 회상.

## 빠른 시작

```powershell
copy secrets.local.json.example secrets.local.json
# 키 입력 후
.\scripts\setup_deploy.ps1
.\scripts\run_dev.ps1
```

## 주요 기능

- 로그인 또는 **게스트 모드** (기기 전용)
- 선제적 기억 소환 (포그라운드 + 백그라운드 15분)
- 썸네일 클라우드 백업 (Supabase Storage)
- 프라이버시 모드 · 대화형 검색 · 회상 탭

## 프로젝트 구조

```
lib/
  main.dart          # 부트스트랩 (~40줄)
  app.dart
  core/              # env, prefs, ocr_config, crash_reporting
  providers/         # Riverpod
  services/          # AI, OCR, recall, storage
  features/          # 화면별 모듈
  utils/             # OCR 유틸
```

## 배포

[DEPLOY.md](DEPLOY.md) · [개인정보 처리방침](docs/PRIVACY_POLICY.md)

## 테스트

```bash
flutter test
```

## Firebase Crashlytics

프로젝트: **memoryos-personal-cognitiv** (연동 완료)

```powershell
.\scripts\setup_firebase.ps1   # 재설정 시
```

Console: https://console.firebase.google.com/project/memoryos-personal-cognitiv/overview

자세한 내용: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

## Play Store 준비

[docs/STORE_READINESS.md](docs/STORE_READINESS.md) · 개인정보 웹: [docs/privacy.html](docs/privacy.html)

CI: `.github/workflows/flutter_ci.yml`
