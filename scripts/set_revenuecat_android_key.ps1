# RevenueCat Android Public SDK 키(goog_...)를 secrets.local.json에 넣고 검증합니다.
# 사용: .\scripts\set_revenuecat_android_key.ps1 -Key "goog_xxxx"
# 키 없이 실행하면 브라우저를 연 뒤 붙여넣기를 기다립니다.

param(
    [string]$Key = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$SecretsPath = Join-Path $Root "secrets.local.json"

if (-not (Test-Path $SecretsPath)) {
    Copy-Item (Join-Path $Root "secrets.local.json.example") $SecretsPath
    Write-Host "secrets.local.json 을 예시에서 만들었습니다. Supabase 등 다른 값도 채운 뒤 다시 실행하세요." -ForegroundColor Yellow
}

# 대시보드 (Apps / API keys)
Start-Process "https://app.revenuecat.com"

if ([string]::IsNullOrWhiteSpace($Key)) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " 1) 열린 사이트에 로그인" -ForegroundColor Cyan
    Write-Host " 2) 왼쪽 Apps → Android(Google Play) 앱" -ForegroundColor Cyan
    Write-Host "    없으면 + New → Google Play" -ForegroundColor Cyan
    Write-Host "    Package: com.theNext.personal_cognitive" -ForegroundColor Cyan
    Write-Host " 3) Public API key (goog_ 로 시작) 복사" -ForegroundColor Cyan
    Write-Host " 4) 아래에 붙여넣고 Enter" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    $Key = Read-Host "goog_ 키 붙여넣기"
}

$Key = $Key.Trim().Trim('"').Trim("'")

if ($Key -notmatch '^goog_') {
    Write-Host "오류: goog_ 로 시작하는 키만 넣으세요. (test_ / appl_ 는 안 됩니다)" -ForegroundColor Red
    Write-Host "입력 앞부분: $($Key.Substring(0, [Math]::Min(8, $Key.Length)))..." -ForegroundColor Yellow
    exit 1
}

$secrets = Get-Content $SecretsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$secrets | Add-Member -NotePropertyName REVENUECAT_ANDROID_KEY -NotePropertyValue $Key -Force
$json = $secrets | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($SecretsPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "저장 완료: REVENUECAT_ANDROID_KEY (길이 $($Key.Length))" -ForegroundColor Green
Write-Host "다음: .\scripts\run_dev.ps1  또는  .\scripts\build_release.ps1" -ForegroundColor Cyan
