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

Write-Host "==> 릴리스 APK 빌드" -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    $apk = "build\app\outputs\flutter-apk\app-release.apk"
    Write-Host ""
    Write-Host "완료: $apk" -ForegroundColor Green
    Write-Host "실기기 설치: adb install -r $apk"
}
