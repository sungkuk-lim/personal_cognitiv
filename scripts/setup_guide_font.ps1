# Noto Sans KR 폰트 다운로드 (PDF 가이드용)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$fontDir = Join-Path $root "assets\fonts"
$fontPath = Join-Path $fontDir "NotoSansKR-Regular.ttf"

if (-not (Test-Path $fontDir)) {
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
}

if ((Test-Path $fontPath) -and ((Get-Item $fontPath).Length -gt 500KB)) {
    Write-Host "폰트 이미 있음: $fontPath" -ForegroundColor Green
    exit 0
}

$malgun = Join-Path $env:WINDIR "Fonts\malgun.ttf"
if (Test-Path $malgun) {
    Write-Host "Windows 맑은 고딕 복사 중..." -ForegroundColor Cyan
    Copy-Item $malgun $fontPath -Force
    Write-Host "완료: $fontPath" -ForegroundColor Green
    exit 0
}

Write-Host "한글 폰트를 찾을 수 없습니다. NotoSansKR-Regular.ttf 를 assets/fonts/ 에 넣어 주세요." -ForegroundColor Red
exit 1
