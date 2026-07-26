# Supabase SQL Editor 열기 + Pro 부여 SQL 안내
# 사용: .\scripts\open_pro_grant.ps1 [-UserUuid "uuid-here"]

param(
    [string]$UserUuid = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$secretsPath = Join-Path $root "secrets.local.json"

if (-not (Test-Path $secretsPath)) {
    Write-Host "secrets.local.json 이 없습니다." -ForegroundColor Red
    exit 1
}

$ref = (Get-Content $secretsPath -Raw | ConvertFrom-Json).SUPABASE_PROJECT_REF
if (-not $ref) {
    Write-Host "SUPABASE_PROJECT_REF 가 secrets.local.json 에 없습니다." -ForegroundColor Red
    exit 1
}

$sqlUrl = "https://supabase.com/dashboard/project/$ref/sql/new"
$authUrl = "https://supabase.com/dashboard/project/$ref/auth/users"

Write-Host ""
Write-Host "1) Authentication → Users (UID 복사)" -ForegroundColor Cyan
Write-Host "   $authUrl"
Write-Host ""
Write-Host "2) SQL Editor 에서 아래 실행" -ForegroundColor Cyan
Write-Host "   $sqlUrl"
Write-Host ""

if ($UserUuid) {
    @"
SELECT upsert_user_subscription(
  '$UserUuid'::uuid,
  'pro',
  'active',
  now() + interval '30 days',
  'manual_test',
  'memoryos_pro_monthly'
);
"@
} else {
    @"
SELECT id, email, created_at FROM auth.users ORDER BY created_at DESC LIMIT 10;

-- 위에서 본인 UID 확인 후:
SELECT upsert_user_subscription(
  'YOUR_USER_UUID'::uuid,
  'pro',
  'active',
  now() + interval '30 days',
  'manual_test',
  'memoryos_pro_monthly'
);
"@
}

Write-Host ""
Start-Process $authUrl
