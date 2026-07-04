# Release APK device QA + store screenshots
param(
    [string]$Device = "",
    [switch]$ScreenshotsOnly,
    [switch]$QaOnly,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Adb([string]$CmdLine) {
    $cmdArgs = $CmdLine.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($Device) { & adb.exe -s $Device @cmdArgs }
    else { & adb.exe @cmdArgs }
}

if (-not $ScreenshotsOnly -and -not $SkipTests) {
    Write-Host "==> Unit tests (P0 regression)" -ForegroundColor Cyan
    flutter test test/graph_entity_audit_test.dart test/memory_entity_reenrich_test.dart test/local_memory_thread_test.dart test/graph_satellite_default_expand_test.dart
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "OK: P0 unit tests" -ForegroundColor Green
}

$devices = (& adb.exe devices) | Select-String "device$"
if (-not $devices) {
    Write-Host "No Android device connected." -ForegroundColor Red
    exit 1
}

$pkg = "com.theNext.personal_cognitive"
$activity = "$pkg/.MainActivity"

if (-not $ScreenshotsOnly) {
    Write-Host "==> QA: package check" -ForegroundColor Cyan
    $installed = Invoke-Adb "shell pm path $pkg" 2>&1
    if ($installed -notmatch $pkg) {
        Write-Host "App not installed. Installing..." -ForegroundColor Yellow
        $apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
        if (-not (Test-Path $apk)) {
            Write-Host "Release APK missing. Run: .\scripts\build_release.ps1" -ForegroundColor Red
            exit 1
        }
        Invoke-Adb "install -r `"$apk`"" | Out-Host
    } else {
        Write-Host "OK: installed"
    }

    Write-Host "==> QA: launch + crash log" -ForegroundColor Cyan
    Invoke-Adb "logcat -c" | Out-Null
    Invoke-Adb "shell am force-stop $pkg" | Out-Null
    Start-Sleep -Seconds 1
    Invoke-Adb "shell am start -n $activity" | Out-Host
    Start-Sleep -Seconds 6

    $fatal = Invoke-Adb "logcat -d -s AndroidRuntime:E" 2>&1 | Select-String "FATAL EXCEPTION"
    if ($fatal) {
        Write-Host "FAIL: crash detected" -ForegroundColor Red
        $fatal | ForEach-Object { Write-Host $_ }
        exit 1
    }
    Write-Host "OK: no FATAL on startup" -ForegroundColor Green

    $focus = Invoke-Adb "shell dumpsys window" 2>&1 | Select-String "mCurrentFocus" | Select-Object -First 1
    Write-Host "Focus: $focus"

    Write-Host "==> QA: deep link graph" -ForegroundColor Cyan
    Invoke-Adb "shell am start -a android.intent.action.VIEW -d memoryos://graph $pkg" | Out-Null
    Start-Sleep -Seconds 3
    $fatal2 = Invoke-Adb "logcat -d -s AndroidRuntime:E" 2>&1 | Select-String "FATAL EXCEPTION"
    if ($fatal2) {
        Write-Host "FAIL: crash on graph deep link" -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: graph deep link" -ForegroundColor Green
}

if (-not $QaOnly) {
    & (Join-Path $PSScriptRoot "capture_store_screenshots.ps1") -Device $Device
}

Write-Host ""
Write-Host "Auto QA done. Manual P0: docs/QA_CHECKLIST.md (edit->graph trust)" -ForegroundColor Green
