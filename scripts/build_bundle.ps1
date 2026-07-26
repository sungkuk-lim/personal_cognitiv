# Play Store AAB 빌드
# 사용: .\scripts\build_bundle.ps1

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# flutter가 stderr로 내보내는 경고를 종료 오류로 취급하지 않도록 합니다.
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

$keyProps = Join-Path $root "android\key.properties"
if (-not (Test-Path $keyProps)) {
    Write-Host "android\key.properties 가 없습니다." -ForegroundColor Yellow
    exit 1
}

Write-Host "==> Release AAB build" -ForegroundColor Cyan

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
    }
    if ($secrets.REVENUECAT_ANDROID_KEY) {
        $defines += "--dart-define=REVENUECAT_ANDROID_KEY=$($secrets.REVENUECAT_ANDROID_KEY)"
        Write-Host "RevenueCat Android 키 주입됨" -ForegroundColor DarkGray
    } else {
        Write-Host "경고: REVENUECAT_ANDROID_KEY 없음 — Paywall만 표시됩니다." -ForegroundColor Yellow
    }
} else {
    Write-Host "경고: secrets.local.json 없음 — 게스트/로컬 저장만 동작합니다." -ForegroundColor Yellow
}

flutter build appbundle --release @defines

if ($LASTEXITCODE -eq 0) {
    $aab = "build\app\outputs\bundle\release\app-release.aab"
    Write-Host ""
    Write-Host "완료: $aab" -ForegroundColor Green
    Write-Host "Play Console 업로드: $aab"
} else {
    Write-Host "빌드 실패 (exit=$LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
