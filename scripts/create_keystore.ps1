#!/usr/bin/env pwsh
# 최초 1회: 릴리스 keystore 생성
# 실행: .\scripts\create_keystore.ps1

$dir = Join-Path $PSScriptRoot "..\android\keystore"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$key = Join-Path $dir "memoryos-release.jks"

if (Test-Path $key) {
    Write-Host "이미 존재: $key"
    exit 0
}

keytool -genkey -v `
  -keystore $key `
  -alias memoryos `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass memoryos123 -keypass memoryos123 `
  -dname "CN=MemoryOS, OU=Dev, O=Personal, L=Seoul, ST=Seoul, C=KR"

Write-Host "생성됨: $key"
Write-Host "android\key.properties.example 를 key.properties 로 복사하고 비밀번호를 입력하세요."
