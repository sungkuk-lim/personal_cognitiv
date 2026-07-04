# GitHub Pages 배포 (docs/ 폴더)
# 사용: .\scripts\deploy_github_pages.ps1
# 사전: gh auth login

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> GitHub Pages 배포 파일 확인" -ForegroundColor Cyan
$required = @(
    "docs\index.html",
    "docs\privacy.html",
    "docs\user_guide.html",
    "docs\.nojekyll"
)
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $root $f))) {
        Write-Host "누락: $f" -ForegroundColor Red
        exit 1
    }
}

Write-Host "==> PDF 가이드 생성" -ForegroundColor Cyan
& (Join-Path $root "scripts\setup_guide_font.ps1")
dart run scripts/generate_user_guide_pdf.dart

Write-Host "==> flutter test" -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> git status (docs + assets/guides)" -ForegroundColor Cyan
git status --short docs assets/guides/modamnet_user_guide.pdf

Write-Host ""
Write-Host "다음을 실행해 Pages에 배포하세요:" -ForegroundColor Yellow
Write-Host "  git add docs assets/guides/modamnet_user_guide.pdf"
Write-Host "  git commit -m `"docs: publish user guide and privacy for GitHub Pages`""
Write-Host "  git push origin main"
Write-Host ""
Write-Host "Pages URL 예:" -ForegroundColor Green
Write-Host "  https://YOUR_USER.github.io/personal_cognitiv/user_guide.html"
Write-Host "  https://YOUR_USER.github.io/personal_cognitiv/privacy.html"
