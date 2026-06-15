#Requires -Version 5.1
<#
  secrets.local.json 을 읽어 Supabase Edge Function + Secret 을 배포합니다.

  사용법:
    1. secrets.local.json.example 을 복사 → secrets.local.json
    2. 값 입력 후:  .\scripts\setup_deploy.ps1
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SecretsPath = Join-Path $Root "secrets.local.json"

if (-not (Test-Path $SecretsPath)) {
    Write-Host "secrets.local.json 이 없습니다." -ForegroundColor Red
    Write-Host "  copy secrets.local.json.example secrets.local.json" -ForegroundColor Yellow
    Write-Host "  후 SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_PROJECT_REF, OPENAI_API_KEY 를 입력하세요."
    exit 1
}

$secrets = Get-Content $SecretsPath -Raw | ConvertFrom-Json
$required = @("SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_PROJECT_REF", "OPENAI_API_KEY")
foreach ($key in $required) {
    if (-not $secrets.$key -or $secrets.$key -match "YOUR_|your_|sk-proj-\.\.\.") {
        Write-Host "secrets.local.json 의 $key 값을 실제 키로 바꿔 주세요." -ForegroundColor Red
        exit 1
    }
}

Set-Location $Root

Write-Host "`n[1/4] Supabase 프로젝트 연결..." -ForegroundColor Cyan
$linked = Test-Path (Join-Path $Root ".supabase\config.toml")
if (-not $linked) {
    supabase link --project-ref $secrets.SUPABASE_PROJECT_REF
    if ($LASTEXITCODE -ne 0) { throw "supabase link 실패. 먼저 'supabase login' 을 실행하세요." }
} else {
    Write-Host "  이미 link 됨 (.supabase/config.toml 존재)" -ForegroundColor DarkGray
}

Write-Host "`n[2/4] OpenAI Secret 등록..." -ForegroundColor Cyan
supabase secrets set "OPENAI_API_KEY=$($secrets.OPENAI_API_KEY)"
if ($LASTEXITCODE -ne 0) { throw "supabase secrets set 실패. supabase login 확인." }

Write-Host "`n[3/4] Edge Function 배포 (openai-proxy)..." -ForegroundColor Cyan
supabase functions deploy openai-proxy
if ($LASTEXITCODE -ne 0) { throw "Edge Function 배포 실패." }

Write-Host "`n[4/4] SQL 마이그레이션 안내" -ForegroundColor Cyan
Write-Host @"

  아래 SQL은 Dashboard에서 한 번만 실행해야 합니다 (CLI로 자동 실행 안 함):
  → https://supabase.com/dashboard/project/$($secrets.SUPABASE_PROJECT_REF)/sql/new
  → supabase/migrations/001_user_rls.sql 내용 붙여넣기 → Run

  Authentication → Providers → Email 활성화
  (개발 중) Authentication → Settings → Confirm email OFF 권장

"@ -ForegroundColor Yellow

Write-Host "배포 스크립트 완료. 앱 실행: .\scripts\run_dev.ps1`n" -ForegroundColor Green
