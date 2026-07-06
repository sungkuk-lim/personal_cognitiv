# secrets.local.json 키 포함 릴리스 APK (PDF 가이드 생성 생략)
# 사용: .\scripts\build_release_secrets.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keyProps = Join-Path $root "android\key.properties"
if (-not (Test-Path $keyProps)) {
    Write-Host "android\key.properties 가 없습니다." -ForegroundColor Red
    exit 1
}

$defines = @()
$secretsPath = Join-Path $root "secrets.local.json"
if (-not (Test-Path $secretsPath)) {
    Write-Host "secrets.local.json 이 없습니다." -ForegroundColor Red
    exit 1
}

$secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
if ($secrets.SUPABASE_URL -and $secrets.SUPABASE_ANON_KEY) {
    $defines += "--dart-define=SUPABASE_URL=$($secrets.SUPABASE_URL)"
    $defines += "--dart-define=SUPABASE_ANON_KEY=$($secrets.SUPABASE_ANON_KEY)"
    $defines += "--dart-define=USE_EDGE_PROXY=true"
}
if ($secrets.REVENUECAT_ANDROID_KEY) {
    $defines += "--dart-define=REVENUECAT_ANDROID_KEY=$($secrets.REVENUECAT_ANDROID_KEY)"
}
if ($secrets.REVENUECAT_IOS_KEY) {
    $defines += "--dart-define=REVENUECAT_IOS_KEY=$($secrets.REVENUECAT_IOS_KEY)"
}

Write-Host "==> Release APK (Supabase + RevenueCat keys from secrets.local.json)" -ForegroundColor Cyan
flutter build apk --release @defines

if ($LASTEXITCODE -eq 0) {
    Write-Host "완료: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
}
