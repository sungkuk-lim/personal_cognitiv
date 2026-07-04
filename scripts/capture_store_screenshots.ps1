# Play Store screenshots (5): timeline, search, graph, replay, settings
param([string]$Device = "")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "store_screenshots"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-AdbExe {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Cmd)
    if ($Device) { & adb.exe -s $Device @Cmd }
    else { & adb.exe @Cmd }
}

$pkg = "com.theNext.personal_cognitive"
$activity = "$pkg/.MainActivity"

# Tab centers from uiautomator (1080x2640)
$tabY = 2376
$tabs = @(135, 405, 675, 945)
$settingsX = 984
$settingsY = 178

function Save-Capture([string]$name) {
    $path = Join-Path $outDir $name
    $remote = "/sdcard/store_cap.png"
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Invoke-AdbExe shell screencap -p $remote 2>&1 | Out-Null
    Invoke-AdbExe pull $remote $path 2>&1 | Out-Null
    Invoke-AdbExe shell rm $remote 2>&1 | Out-Null
    $ErrorActionPreference = $prevEAP
    if (-not (Test-Path $path)) { throw "Screenshot failed: $name" }
    $bytes = (Get-Item $path).Length
    Write-Host "Saved: $name ($bytes bytes)" -ForegroundColor Green
}

function Tap([int]$x, [int]$y) {
    Invoke-AdbExe shell input tap $x $y | Out-Null
    Start-Sleep -Milliseconds 900
}

Invoke-AdbExe shell input keyevent KEYCODE_WAKEUP | Out-Null
Invoke-AdbExe shell am force-stop $pkg | Out-Null
Start-Sleep -Seconds 1
Invoke-AdbExe shell am start -n $activity | Out-Null
Start-Sleep -Seconds 5

Tap $tabs[0] $tabY
Save-Capture "01_timeline.png"

Tap $tabs[1] $tabY
Save-Capture "02_search.png"

Tap $tabs[2] $tabY
Save-Capture "03_graph.png"

Tap $tabs[3] $tabY
Save-Capture "04_replay.png"

Tap $settingsX $settingsY
Start-Sleep -Seconds 1
Save-Capture "05_settings.png"

Invoke-AdbExe shell input keyevent KEYCODE_BACK | Out-Null
Write-Host ""
Write-Host "Done: $outDir" -ForegroundColor Cyan
