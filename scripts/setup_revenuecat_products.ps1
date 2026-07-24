# RevenueCat: Products + entitlement pro + Offering setup via API v2
# Usage:
#   .\scripts\setup_revenuecat_products.ps1 -SecretKey "sk_xxxx"
# Or set env REVENUECAT_SECRET_KEY

param(
    [string]$SecretKey = $env:REVENUECAT_SECRET_KEY,
    [string]$ProjectId = "projd56193c1",
    [string]$AppId = "app7e0a64b285"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SecretKey)) {
    Write-Host "Secret API key (sk_...) 가 필요합니다." -ForegroundColor Yellow
    Write-Host "RevenueCat → Project settings → API keys → Secret key 복사 후:" -ForegroundColor Cyan
    Write-Host '  .\scripts\setup_revenuecat_products.ps1 -SecretKey "sk_..."' -ForegroundColor Cyan
    exit 1
}

$SecretKey = $SecretKey.Trim().Trim('"').Trim("'")
if ($SecretKey -notmatch '^sk_') {
    Write-Host "오류: Secret key는 sk_ 로 시작해야 합니다. (goog_/test_ 불가)" -ForegroundColor Red
    exit 1
}

$headers = @{
    Authorization = "Bearer $SecretKey"
    "Content-Type"  = "application/json"
}
$base = "https://api.revenuecat.com/v2"

function Invoke-Rc {
    param([string]$Method, [string]$Path, $Body = $null)
    $uri = "$base$Path"
    $params = @{ Uri = $uri; Method = $Method; Headers = $headers }
    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }
    try {
        return Invoke-RestMethod @params
    } catch {
        $msg = $_.ErrorDetails.Message
        if (-not $msg) { $msg = $_.Exception.Message }
        throw "$Method $Path => $msg"
    }
}

Write-Host "== RevenueCat setup ==" -ForegroundColor Cyan
Write-Host "project=$ProjectId app=$AppId"

# 1) List existing products
$existing = Invoke-Rc GET "/projects/$ProjectId/products?limit=50"
$byStore = @{}
foreach ($p in $existing.items) {
    $byStore[$p.store_identifier] = $p
    Write-Host ("existing product: " + $p.store_identifier + " id=" + $p.id)
}

$want = @(
    @{ store = "memoryos_pro_monthly:monthly"; name = "MemoryOS Pro Monthly"; duration = "P1M" },
    @{ store = "memoryos_pro_annual:annual";  name = "MemoryOS Pro Annual";  duration = "P1Y" }
)

$productIds = @()
foreach ($w in $want) {
    if ($byStore.ContainsKey($w.store)) {
        $productIds += $byStore[$w.store].id
        Write-Host ("OK product exists: " + $w.store) -ForegroundColor Green
        continue
    }
    # legacy bare id (should not create — Play needs subscriptionId:basePlanId)
    $bare = ($w.store -split ':')[0]
    if ($byStore.ContainsKey($bare)) {
        $productIds += $byStore[$bare].id
        Write-Host ("OK product exists (legacy): " + $bare) -ForegroundColor Yellow
        continue
    }
    $body = @{
        store_identifier = $w.store
        app_id           = $AppId
        type             = "subscription"
        display_name     = $w.name
    }
    $created = Invoke-Rc POST "/projects/$ProjectId/products" $body
    $productIds += $created.id
    Write-Host ("CREATED product: " + $w.store + " id=" + $created.id) -ForegroundColor Green
}

# 2) Entitlement pro (lookup_key 소문자 — 앱 SubscriptionConfig.entitlementPro 와 일치)
$ents = Invoke-Rc GET "/projects/$ProjectId/entitlements?limit=50"
$ent = $ents.items | Where-Object { $_.lookup_key -ceq "pro" } | Select-Object -First 1
if (-not $ent) {
    $ent = Invoke-Rc POST "/projects/$ProjectId/entitlements" @{
        lookup_key   = "pro"
        display_name = "MemoryOS Pro"
    }
    Write-Host ("CREATED entitlement pro id=" + $ent.id) -ForegroundColor Green
} else {
    Write-Host ("OK entitlement pro id=" + $ent.id) -ForegroundColor Green
}

# Attach products
Invoke-Rc POST "/projects/$ProjectId/entitlements/$($ent.id)/actions/attach_products" @{
    product_ids = $productIds
} | Out-Null
Write-Host "ATTACHED products to pro" -ForegroundColor Green

# 3) Offering current
$offs = Invoke-Rc GET "/projects/$ProjectId/offerings?limit=50"
$off = $offs.items | Where-Object { $_.lookup_key -eq "default" -or $_.lookup_key -eq "current" -or $_.is_current -eq $true } | Select-Object -First 1
if (-not $off) {
    $off = $offs.items | Select-Object -First 1
}
if (-not $off) {
    $off = Invoke-Rc POST "/projects/$ProjectId/offerings" @{
        lookup_key   = "default"
        display_name = "Default"
    }
    Write-Host ("CREATED offering id=" + $off.id) -ForegroundColor Green
} else {
    Write-Host ("OK offering lookup=" + $off.lookup_key + " id=" + $off.id) -ForegroundColor Green
}

# Make current if endpoint exists
try {
    Invoke-Rc POST "/projects/$ProjectId/offerings/$($off.id)/actions/set_current" @{} | Out-Null
    Write-Host "SET offering current" -ForegroundColor Green
} catch {
    Write-Host ("set_current skipped: " + $_) -ForegroundColor Yellow
}

# Packages
$pkgs = Invoke-Rc GET "/projects/$ProjectId/offerings/$($off.id)/packages?limit=50"
$pkgByKey = @{}
foreach ($pk in $pkgs.items) { $pkgByKey[$pk.lookup_key] = $pk }

$monthlyProd = ($existing.items + @()) 
# refresh products
$allProds = Invoke-Rc GET "/projects/$ProjectId/products?limit=50"
$idMonthly = ($allProds.items | Where-Object {
    $_.store_identifier -eq "memoryos_pro_monthly:monthly" -or $_.store_identifier -eq "memoryos_pro_monthly"
} | Select-Object -First 1).id
$idAnnual  = ($allProds.items | Where-Object {
    $_.store_identifier -eq "memoryos_pro_annual:annual" -or $_.store_identifier -eq "memoryos_pro_annual"
} | Select-Object -First 1).id

function Ensure-Package {
    param($Lookup, $Display, $ProductId)
    if ($pkgByKey.ContainsKey($Lookup)) {
        $pkg = $pkgByKey[$Lookup]
        Write-Host ("OK package " + $Lookup) -ForegroundColor Green
    } else {
        $pkg = Invoke-Rc POST "/projects/$ProjectId/offerings/$($off.id)/packages" @{
            lookup_key   = $Lookup
            display_name = $Display
        }
        Write-Host ("CREATED package " + $Lookup) -ForegroundColor Green
    }
    if ($ProductId) {
        try {
            Invoke-Rc POST "/projects/$ProjectId/packages/$($pkg.id)/actions/attach_products" @{
                product_ids = @($ProductId)
            } | Out-Null
            Write-Host ("ATTACHED $ProductId -> $Lookup") -ForegroundColor Green
        } catch {
            # some APIs use product_id singular
            try {
                Invoke-Rc POST "/projects/$ProjectId/packages/$($pkg.id)" @{
                    product_id = $ProductId
                } | Out-Null
            } catch {
                Write-Host ("attach package warn: " + $_) -ForegroundColor Yellow
            }
        }
    }
}

Ensure-Package -Lookup '$rc_monthly' -Display 'Monthly' -ProductId $idMonthly
Ensure-Package -Lookup '$rc_annual' -Display 'Annual' -ProductId $idAnnual

Write-Host ""
Write-Host "Done. Dashboard에서 Products / Entitlements / Offerings 확인하세요." -ForegroundColor Cyan
