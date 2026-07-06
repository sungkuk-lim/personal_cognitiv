# Play Store AAB 빌드
# 사용: .\scripts\build_bundle.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

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
    }
}

flutter build appbundle --release @defines

if ($LASTEXITCODE -eq 0) {
    $aab = "build\app\outputs\bundle\release\app-release.aab"
    Write-Host ""
    Write-Host "완료: $aab" -ForegroundColor Green
    Write-Host "Play Console 업로드: $aab"
}
