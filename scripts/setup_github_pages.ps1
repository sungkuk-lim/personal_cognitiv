# GitHub Pages 배포 (개인정보 처리방침)
# 사용: .\scripts\setup_github_pages.ps1 [-RepoUrl https://github.com/USER/personal_cognitiv.git]

param(
    [string]$RepoUrl = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git이 설치되어 있지 않습니다." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path ".git")) {
    Write-Host "==> Git 저장소 초기화" -ForegroundColor Cyan
    git init -b main
}

$status = git status --porcelain
if ($status) {
    Write-Host "==> 변경 사항 스테이징 (docs/privacy.html 등)" -ForegroundColor Cyan
    git add docs/privacy.html docs/index.html docs/PRIVACY_POLICY.md README.md
    git add lib android pubspec.yaml scripts .github docs/FIREBASE_SETUP.md docs/STORE_READINESS.md
    git add -A
    git reset HEAD secrets.local.json android/key.properties android/keystore/ 2>$null
    if (-not (git rev-parse HEAD 2>$null)) {
        git commit -m "Initial commit: MemoryOS app and privacy policy for GitHub Pages"
    } else {
        git commit -m "Add privacy policy page for GitHub Pages" 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Host "커밋할 변경 없음 또는 이미 커밋됨" }
    }
}

$remote = git remote get-url origin 2>$null
if (-not $remote -and $RepoUrl) {
    git remote add origin $RepoUrl
    $remote = $RepoUrl
}

Write-Host ""
Write-Host "=== GitHub Pages 설정 안내 ===" -ForegroundColor Green
Write-Host ""
if ($remote) {
    Write-Host "원격: $remote"
    Write-Host "푸시: git push -u origin main"
} else {
    Write-Host "1. GitHub에서 새 저장소 생성 (예: personal_cognitiv)"
    Write-Host "2. 연결:"
    Write-Host "   git remote add origin https://github.com/YOUR_USER/personal_cognitiv.git"
    Write-Host "   git push -u origin main"
}
Write-Host ""
Write-Host "3. GitHub 저장소 → Settings → Pages"
Write-Host "   Source: Deploy from a branch"
Write-Host "   Branch: main / folder: /docs"
Write-Host ""
Write-Host "4. 배포 후 URL (예시):"
Write-Host "   https://YOUR_USER.github.io/personal_cognitiv/privacy.html"
Write-Host "   Play Console 개인정보 처리방침 URL에 위 주소 입력"
Write-Host ""
