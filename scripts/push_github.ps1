# GitHub 저장소 생성 + 푸시 (gh 로그인 완료 후 실행)
# 사용: .\scripts\push_github.ps1

$ErrorActionPreference = "Stop"
$env:Path = "C:\Program Files\GitHub CLI;$env:Path"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> GitHub 로그인 확인" -ForegroundColor Cyan
gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host "먼저 실행: gh auth login" -ForegroundColor Red
    exit 1
}

$repoName = "personal_cognitiv"
$pending = git status --porcelain
if ($pending) {
    Write-Host "==> 미커밋 변경 사항 커밋" -ForegroundColor Cyan
    git add docs/GITHUB_PAGES.md scripts/use_gh.ps1 scripts/push_github.ps1 2>$null
    git add -A
    git reset HEAD secrets.local.json android/key.properties android/keystore/ 2>$null
    $status = git status --porcelain
    if ($status) {
        git -c user.name="MemoryOS" -c user.email="memoryos@users.noreply.github.com" `
            commit -m "Update GitHub Pages docs and gh helper scripts"
    }
}

$remote = git remote get-url origin 2>$null
if ($remote) {
    Write-Host "==> 기존 origin으로 푸시: $remote" -ForegroundColor Cyan
    git push -u origin main
} else {
    Write-Host "==> 저장소 생성 및 푸시: $repoName" -ForegroundColor Cyan
    gh repo create $repoName --public --source=. --remote=origin --push
}

if ($LASTEXITCODE -eq 0) {
    $user = (gh api user -q .login)
    Write-Host ""
    Write-Host "완료!" -ForegroundColor Green
    Write-Host "저장소: https://github.com/$user/$repoName"
    Write-Host ""
    Write-Host "Pages 설정:" -ForegroundColor Cyan
    Write-Host "  https://github.com/$user/$repoName/settings/pages"
    Write-Host "  Branch: main / Folder: /docs"
    Write-Host ""
    Write-Host "개인정보 처리방침 URL:"
    Write-Host "  https://$user.github.io/$repoName/privacy.html" -ForegroundColor Yellow
}
