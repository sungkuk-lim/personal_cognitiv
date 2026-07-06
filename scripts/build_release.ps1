# 릴리스 APK 빌드
# 사용: .\scripts\build_release.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keyProps = Join-Path $root "android\key.properties"
if (-not (Test-Path $keyProps)) {
    Write-Host "android\key.properties 가 없습니다." -ForegroundColor Yellow
    Write-Host "  1. .\scripts\create_keystore.ps1"
    Write-Host "  2. copy android\key.properties.example android\key.properties"
    Write-Host "  3. 비밀번호·경로 입력 후 다시 실행"
    exit 1
}

Write-Host "==> Release APK build" -ForegroundColor Cyan

Write-Host "==> User guide PDF" -ForegroundColor Cyan
& (Join-Path $root "scripts\setup_guide_font.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run scripts/generate_user_guide_pdf.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$defines = @()
$secretsPath = Join-Path $root "secrets.local.json"
if (Test-Path $secretsPath) {
    $secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
    if ($secrets.SUPABASE_URL -and $secrets.SUPABASE_ANON_KEY) {
        $defines = @(
            "--dart-define=SUPABASE_URL=$($secrets.SUPABASE_URL)",
            "--dart-define=SUPABASE_ANON_KEY=$($secrets.SUPABASE_ANON_KEY)",
            "--dart-define=USE_EDGE_PROXY=true"
        )
        Write-Host "Using secrets.local.json for Supabase" -ForegroundColor DarkGray
    }
    if ($secrets.REVENUECAT_ANDROID_KEY) {
        $defines += "--dart-define=REVENUECAT_ANDROID_KEY=$($secrets.REVENUECAT_ANDROID_KEY)"
        Write-Host "Using RevenueCat Android key" -ForegroundColor DarkGray
    }
    if ($secrets.REVENUECAT_IOS_KEY) {
        $defines += "--dart-define=REVENUECAT_IOS_KEY=$($secrets.REVENUECAT_IOS_KEY)"
    }
} else {
    Write-Host "No secrets.local.json — guest/local save still works; cloud/AI needs keys" -ForegroundColor Yellow
}

flutter build apk --release @defines

if ($LASTEXITCODE -eq 0) {
    $apk = "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host ""
    Write-Host "완료: $apk" -ForegroundColor Green
    Write-Host "실기기 설치: adb install -r $apk"
}
