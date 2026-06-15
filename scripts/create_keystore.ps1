#!/usr/bin/env pwsh
# 최초 1회: 릴리스 keystore + key.properties 생성
# 실행: .\scripts\create_keystore.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "android\keystore"
$key = Join-Path $dir "memoryos-release.jks"
$keyProps = Join-Path $root "android\key.properties"
$storePass = "memoryos123"
$keyPass = "memoryos123"

New-Item -ItemType Directory -Force -Path $dir | Out-Null

if (-not (Test-Path $key)) {
    keytool -genkey -v `
      -keystore $key `
      -alias memoryos `
      -keyalg RSA -keysize 2048 -validity 10000 `
      -storepass $storePass -keypass $keyPass `
      -dname "CN=MemoryOS, OU=Dev, O=Personal, L=Seoul, ST=Seoul, C=KR"
    Write-Host "생성됨: $key" -ForegroundColor Green
} else {
    Write-Host "이미 존재: $key"
}

if (-not (Test-Path $keyProps)) {
    @"
storePassword=$storePass
keyPassword=$keyPass
keyAlias=memoryos
storeFile=../keystore/memoryos-release.jks
"@ | Set-Content -Path $keyProps -Encoding UTF8
    Write-Host "생성됨: android\key.properties" -ForegroundColor Green
} else {
    Write-Host "이미 존재: android\key.properties"
}

Write-Host ""
Write-Host "릴리스 빌드: .\scripts\build_release.ps1"
Write-Host "배포 전 keystore 비밀번호 변경을 권장합니다." -ForegroundColor Yellow
