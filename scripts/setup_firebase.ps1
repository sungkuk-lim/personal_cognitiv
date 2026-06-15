# Firebase Crashlytics 자동 설정
# 사용: .\scripts\setup_firebase.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> flutterfire_cli 설치" -ForegroundColor Cyan
dart pub global activate flutterfire_cli

$flutterfire = "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat"
if (-not (Test-Path $flutterfire)) {
    $flutterfire = "flutterfire"
}

Write-Host ""
Write-Host "==> Firebase 프로젝트 연동" -ForegroundColor Cyan
Write-Host "    - 새 프로젝트 생성 또는 기존 프로젝트 선택"
Write-Host "    - Android 패키지: com.theNext.personal_cognitive"
Write-Host ""

& $flutterfire configure --project=memoryos-personal-cognitiv --platforms=android --yes 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "대화형 설정으로 전환합니다..." -ForegroundColor Yellow
    & $flutterfire configure --platforms=android
}

if (Test-Path "android\app\google-services.json") {
    Write-Host ""
    Write-Host "OK: google-services.json 생성됨" -ForegroundColor Green
} else {
    Write-Host "경고: google-services.json 없음 — Firebase Console에서 수동 다운로드하세요." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Cyan
Write-Host "  1. Firebase Console > Crashlytics > 시작하기"
Write-Host "  2. flutter build apk --release 로 릴리스 빌드 후 테스트"
Write-Host "  3. 자세한 내용: docs/FIREBASE_SETUP.md"
