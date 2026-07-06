param(
    [string]$Device = "R5CX70Z5LJB",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pkg = "com.theNext.personal_cognitive"
$activity = "$pkg/.MainActivity"
$apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
$qaDir = Join-Path $root "qa_device_artifacts"
$uiLocal = Join-Path $qaDir "ui_dump.xml"
$logFile = Join-Path $qaDir "qa_manual_log.txt"
$strings = Get-Content (Join-Path $qaDir "qa_strings.json") -Raw -Encoding UTF8 | ConvertFrom-Json

function Log([string]$msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor Cyan
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

function Invoke-Adb([string[]]$Cmd) { & adb.exe -s $Device @Cmd }

function Force-StopApp { Invoke-Adb @("shell", "am", "force-stop", $pkg) | Out-Null; Start-Sleep 1 }
function Launch-App { Invoke-Adb @("shell", "am", "start", "-n", $activity) | Out-Null; Start-Sleep 5 }
function Tap([int]$x, [int]$y, [int]$ms = 900) { Invoke-Adb @("shell", "input", "tap", "$x", "$y") | Out-Null; Start-Sleep -Milliseconds $ms }
function Swipe([int]$x1, [int]$y1, [int]$x2, [int]$y2) { Invoke-Adb @("shell", "input", "swipe", "$x1", "$y1", "$x2", "$y2", "450") | Out-Null; Start-Sleep 700 }
function Back { Invoke-Adb @("shell", "input", "keyevent", "KEYCODE_BACK") | Out-Null; Start-Sleep 600 }

function Dump-Ui {
    Invoke-Adb @("shell", "uiautomator", "dump", "/sdcard/ui_dump.xml") | Out-Null
    Invoke-Adb @("pull", "/sdcard/ui_dump.xml", $uiLocal) | Out-Null
    return Get-Content $uiLocal -Raw -Encoding UTF8
}

function Find-NodeCenter([string]$ui, [string]$needle) {
    if ([string]::IsNullOrWhiteSpace($needle)) { return $null }
    $escaped = [regex]::Escape($needle)
    foreach ($attr in @('text', 'content-desc')) {
        foreach ($pat in @(
            "$attr=`"$escaped`"[^>]*bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"",
            "bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"[^>]*$attr=`"$escaped`""
        )) {
            $m = [regex]::Match($ui, $pat)
            if ($m.Success) {
                return @{
                    X = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
                    Y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
                }
            }
        }
    }
    return $null
}

function Tap-Needle([string]$needle, [int]$retries = 8) {
    for ($i = 0; $i -lt $retries; $i++) {
        $ui = Dump-Ui
        $pt = Find-NodeCenter $ui $needle
        if ($pt) { Tap $pt.X $pt.Y 1200; Log "Tapped: $needle"; return $true }
        Start-Sleep 600
    }
    Log "WARN missing: $needle"
    return $false
}

function Dismiss-Overlays {
    foreach ($label in $strings.dismiss_labels) {
        $ui = Dump-Ui
        $pt = Find-NodeCenter $ui ([string]$label)
        if ($pt) { Tap $pt.X $pt.Y 800 }
    }
}

function Scroll-Settings { 1..4 | ForEach-Object { Swipe 540 2100 540 800 } }

function Screenshot([string]$name) {
    $path = Join-Path $qaDir $name
    Invoke-Adb @("shell", "screencap", "-p", "/sdcard/qa_cap.png") | Out-Null
    Invoke-Adb @("pull", "/sdcard/qa_cap.png", $path) | Out-Null
    Log "Shot: $name"
}

if (-not $SkipInstall) {
    Invoke-Adb @("install", "-r", $apk) | Out-Host
    if (Test-Path 'F:\') { Copy-Item $apk 'F:\personal_cognitive-release.apk' -Force; Log 'Copied F drive apk' }
}

if (Test-Path $logFile) { Remove-Item $logFile }
Log '=== QA manual device ==='

$tabY = 2376
$settingsX = 984
$settingsY = 178

Log '--- 1 re-enrich ---'
Invoke-Adb @('push', (Join-Path $qaDir 'qa_stale_reenrich.json'), '/sdcard/Download/qa_stale_reenrich.json') | Out-Null
Force-StopApp
Launch-App
Dismiss-Overlays
Tap $settingsX $settingsY
Start-Sleep 2
Dismiss-Overlays
Scroll-Settings
Screenshot '01_settings_before_import.png'
Tap-Needle ([string]$strings.backup_import) | Out-Null
Start-Sleep 2
if (-not (Tap-Needle 'qa_stale_reenrich.json')) {
    Tap-Needle 'Download' | Out-Null
    Tap-Needle 'qa_stale_reenrich' | Out-Null
}
Start-Sleep 3
Screenshot '02_after_import.png'
Force-StopApp
Launch-App
Dismiss-Overlays
Start-Sleep 4
$ui1 = Dump-Ui
Screenshot '03_reenrich_snackbar.png'
$test1Snack = $ui1.Contains([string]$strings.reenrich_snackbar)
Log "reenrich snackbar: $test1Snack"
Tap 675 $tabY
Start-Sleep 3
$uiGraph = Dump-Ui
$test1Graph = -not $uiGraph.Contains([string]$strings.stale_name)
Log "graph no stale: $test1Graph"

Log '--- 2 cleanup ---'
Tap $settingsX $settingsY
Start-Sleep 2
Scroll-Settings
$uiSet = Dump-Ui
$test2Banner = $uiSet.Contains([string]$strings.cleanup_banner)
Log "cleanup banner: $test2Banner"
Screenshot '04_cleanup_banner.png'
Tap-Needle ([string]$strings.graph_cleanup) | Out-Null
Start-Sleep 2
$uiDlg = Dump-Ui
Screenshot '05_cleanup_dialog.png'
if ($uiDlg.Contains([string]$strings.cleanup_run)) {
    Tap-Needle ([string]$strings.cleanup_run) | Out-Null
    Start-Sleep 4
    $test2Run = 'executed'
} else {
    $test2Run = 'none'
}
Screenshot '06_after_cleanup.png'
Back

Log '--- 3 local search ---'
Tap $settingsX $settingsY
Start-Sleep 1
Tap 930 1180 1000
Back
Tap 405 $tabY
Start-Sleep 2
Tap 540 2200 800
Start-Sleep 2
foreach ($kb in $strings.keyboard_labels) { Tap-Needle ([string]$kb) | Out-Null }
Invoke-Adb @('shell', 'input', 'text', 'MS') | Out-Null
Invoke-Adb @('shell', 'input', 'keyevent', '66') | Out-Null
Start-Sleep 5
$uiLocal = Dump-Ui
$test3Local = $uiLocal.Contains([string]$strings.local_banner) -or $uiLocal.Contains([string]$strings.local_keyword_banner)
Log "local banner: $test3Local"
Screenshot '07_search_local.png'
Back
Back

Log '--- 4 pro search ---'
Tap $settingsX $settingsY
Start-Sleep 1
Tap 930 1180 1000
Back
Tap 405 $tabY
Start-Sleep 2
Tap 540 2200
Start-Sleep 2
foreach ($kb in $strings.keyboard_labels) { Tap-Needle ([string]$kb) | Out-Null }
Invoke-Adb @('shell', 'input', 'text', 'MS') | Out-Null
Invoke-Adb @('shell', 'input', 'keyevent', '66') | Out-Null
Start-Sleep 12
$uiPro = Dump-Ui
$test4Pro = (-not $uiPro.Contains([string]$strings.local_keyword_banner)) -and (
    $uiPro.Contains([string]$strings.match_maru) -or $uiPro.Contains([string]$strings.match_walk)
)
$test4Guest = $uiPro.Contains([string]$strings.login_msg) -or $uiPro.Contains([string]$strings.guest_msg) -or $uiPro.Contains('Pro')
Log "pro ai: $test4Pro guest-block: $test4Guest"
Screenshot '08_search_pro.png'

$summary = [ordered]@{
    date = (Get-Date).ToString('o')
    device = $Device
    f_drive_copy = (Test-Path 'F:\personal_cognitive-release.apk')
    test1_reenrich_snackbar = $test1Snack
    test1_graph_no_stale = $test1Graph
    test2_cleanup_banner = $test2Banner
    test2_cleanup_run = $test2Run
    test3_local_fallback = $test3Local
    test4_pro_search = $test4Pro
    test4_guest_or_login = $test4Guest
}
$summary | ConvertTo-Json | Set-Content (Join-Path $qaDir 'qa_manual_result.json') -Encoding UTF8
Log 'Done'
$summary | ConvertTo-Json | Write-Host
