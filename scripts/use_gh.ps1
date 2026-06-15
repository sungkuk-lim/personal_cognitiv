# GitHub CLI PATH 보정 (설치 직후 터미널에서 gh 인식 안 될 때)
# 사용: . .\scripts\use_gh.ps1

$ghDir = "C:\Program Files\GitHub CLI"
if (Test-Path "$ghDir\gh.exe") {
    if ($env:Path -notlike "*$ghDir*") {
        $env:Path = "$ghDir;$env:Path"
    }
    Write-Host "gh 준비됨: $(gh --version)" -ForegroundColor Green
} else {
    Write-Host "GitHub CLI가 없습니다. 설치:" -ForegroundColor Yellow
    Write-Host "  winget install GitHub.cli"
}
