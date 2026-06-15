# Firebase Crashlytics 설정 (MemoryOS)

무료 Firebase 프로젝트로 크래시·비치명적 오류를 수집합니다.

프로젝트 ID: `memoryos-personal-cognitiv`  
Console: https://console.firebase.google.com/project/memoryos-personal-cognitiv/overview

## 1. 사전 준비

- [Firebase Console](https://console.firebase.google.com/) 계정
- Flutter SDK · Android Studio (선택)

## 2. 자동 설정 (권장)

PowerShell에서 프로젝트 루트:

```powershell
.\scripts\setup_firebase.ps1
```

스크립트가 수행하는 작업:

1. `flutterfire_cli` 설치
2. `flutterfire configure` 실행 → Android 앱 `com.theNext.personal_cognitive` 선택
3. `lib/firebase_options.dart`, `android/app/google-services.json` 자동 생성

## 3. 수동 설정

1. Firebase Console → **프로젝트 추가** → Android
2. 패키지명: `com.theNext.personal_cognitive`
3. `google-services.json` 다운로드 → `android/app/google-services.json`
4. 터미널:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID --platforms=android
```

## 4. Crashlytics 콘솔에서 활성화

1. Firebase Console → **Crashlytics** → **시작하기**
2. Android 앱 선택 후 안내에 따라 Gradle 플러그인 확인 (이미 적용됨)

## 5. 동작 확인

```powershell
.\scripts\run_dev.ps1
```

- **디버그 빌드**: Crashlytics 수집 **OFF** (개발 중 노이즈 방지)
- **릴리스 빌드**: 수집 **ON**

```powershell
flutter build apk --release
```

앱에서 테스트 크래시(개발용):

```dart
// 개발 중에만 — 배포 전 제거
FirebaseCrashlytics.instance.crash();
```

비치명적 오류는 코드에서 자동 전송됩니다 (`CrashReporting.recordError`).

## 6. 로컬에서 Crashlytics 끄기

```powershell
flutter run --dart-define=ENABLE_CRASHLYTICS=false
```

## 7. placeholder 상태

`google-services.json`에 `Placeholder` 키가 있으면 Firebase 초기화를 건너뜁니다.  
위 2~3단계를 완료하면 실제 연동이 활성화됩니다.
