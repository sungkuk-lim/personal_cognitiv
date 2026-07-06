#Requires -Version 5.1
<#
  secrets.local.json 기반으로 flutter run (Edge Proxy 사용)

  사용법: .\scripts\run_dev.ps1
  옵션:   .\scripts\run_dev.ps1 -Release   (APK 빌드)
#>
param(
    [switch]$Release
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SecretsPath = Join-Path $Root "secrets.local.json"

if (-not (Test-Path $SecretsPath)) {
    Write-Host "secrets.local.json 이 없습니다. secrets.local.json.example 을 참고해 만드세요." -ForegroundColor Red
    exit 1
}

$secrets = Get-Content $SecretsPath -Raw | ConvertFrom-Json
$url = $secrets.SUPABASE_URL
$anon = $secrets.SUPABASE_ANON_KEY

if (-not $url -or -not $anon) {
    Write-Host "SUPABASE_URL, SUPABASE_ANON_KEY 가 필요합니다." -ForegroundColor Red
    exit 1
}

Set-Location $Root

$defines = @(
    "--dart-define=SUPABASE_URL=$url",
    "--dart-define=SUPABASE_ANON_KEY=$anon",
    "--dart-define=USE_EDGE_PROXY=true"
)

if ($Release) {
    Write-Host "Release APK 빌드 중..." -ForegroundColor Cyan
    flutter build apk --release @defines
    Write-Host "출력: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
    Write-Host "flutter run (Edge Proxy ON)..." -ForegroundColor Cyan
    flutter run @defines
}
