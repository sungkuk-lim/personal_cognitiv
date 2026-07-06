# GitHub Pages 배포 (docs/ 폴더)
# 사용: .\scripts\deploy_pages.ps1 [-Message "docs: update site"]

param(
    [string]$Message = "docs: deploy modamnet site and policies"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$paths = @(
    "docs/",
    ".github/workflows/pages.yml",
    "lib/core/app_urls.dart"
)

Write-Host "Staging Pages-related files..."
git add @paths

$status = git status --short
if (-not $status) {
    Write-Host "Nothing to commit for Pages."
    exit 0
}

git commit -m $Message
git push origin HEAD

Write-Host ""
Write-Host "Done. Enable GitHub Pages:"
Write-Host "  https://github.com/sungkuk-lim/personal_cognitiv/settings/pages"
Write-Host "  Source: GitHub Actions"
Write-Host ""
Write-Host "Site URL:"
Write-Host "  https://sungkuk-lim.github.io/personal_cognitiv/"
