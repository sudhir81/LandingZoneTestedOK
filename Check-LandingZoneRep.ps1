<# 
Azure Landing Zone HTML Health Report
- Windows 11 + Azure CLI
- Generates C:\tmp\LandingZone_Report.html
#>

param(
  [string]$SubscriptionId = "4c13f2a5-9a74-4ad1-b6a6-f99adc18cb3b",
  [string]$Location       = "East US",
  [string]$ReportPath     = "C:\tmp\LandingZone_Report.html"
)

# -----------------------------
# Helpers
# -----------------------------
function Ensure-AzLogin {
  Write-Host "🔐 Checking Azure CLI login..."
  az account show --only-show-errors | Out-Null 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in — opening browser..." -ForegroundColor Yellow
    az login --only-show-errors | Out-Null
  }
  az account set --subscription $SubscriptionId --only-show-errors | Out-Null
}

function Get-AzJson {
  param([string]$Cmd)
  $json = Invoke-Expression $Cmd 2>$null
  if ([string]::IsNullOrWhiteSpace($json)) { return @() }
  try { return $json | ConvertFrom-Json } catch { return @() }
}

function Badge {
  param([string]$text, [string]$state) # state: ok|warn|err
  $color = switch ($state) {
    "ok"   { "#10B981" } # green
    "warn" { "#F59E0B" } # amber
    "err"  { "#EF4444" } # red
    default { "#6B7280" } # gray
  }
  return "<span class='badge' style='background:$color'>$text</span>"
}

function TableHtml {
  param([object[]]$Rows, [string[]]$Columns, [string]$Title = "")
  if (-not $Rows -or $Rows.Count -eq 0) {
    return "<div class='card'><div class='card-header'>$Title</div><div class='empty'>No data</div></div>"
  }
  $thead = ($Columns | ForEach-Object { "<th>$_</th>" }) -join ""
  $trs = foreach ($r in $Rows) {
    $tds = foreach ($c in $Columns) {
      $val = $r.$c
      if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
        $val = ($val -join ", ")
      }
      "<td>$([System.Web.HttpUtility]::HtmlEncode($val))</td>"
    }
    "<tr>$($tds -join '')</tr>"
  }
  @"
<div class='card'>
  <div class='card-header'>$Title</div>
  <div class='table-wrap'>
    <table>
      <thead><tr>$thead</tr></thead>
      <tbody>
        $($trs -join "`n")
      </tbody>
    </table>
  </div>
</div>
"@
}

function RenderSection {
  param(
    [string]$Title,
    [string]$Status,     # ok|warn|err
    [string]$SummaryHtml,
    [string]$BodyHtml
  )
  $badge = Badge $Status.ToUpper() $Status
  @"
<section>
  <h2>$Title $badge</h2>
  $SummaryHtml
  $BodyHtml
</section>
"@
}

# -----------------------------
# Start
# -----------------------------
Ensure-AzLogin

# Data fetch (all JSON so we can render tables)
$sub = Get-AzJson "az account show --query '{name:name, id:id, tenant:tenantId, user:user.name}' -o json"
$rgs = Get-AzJson "az group list -o json | jq '[.[] | {Name:.name, Location:.location}]'"
if (-not $rgs) { $rgs = Get-AzJson "az group list --query '[].{Name:name, Location:location}' -o json" } # fallback

$vnets = Get-AzJson "az network vnet list --query '[].{Name:name, RG:resourceGroup, Location:location, Address:addressSpace.addressPrefixes}' -o json"
$subnets = Get-AzJson "az network vnet subnet list --vnet-name '*' --resource-group '*' -o json" # this wildcard isn't supported; we'll derive per vnet
# derive subnets per vnet (safe mode)
$subnetRows = @()
foreach ($v in $vnets) {
  $sn = Get-AzJson "az network vnet subnet list --vnet-name `"$($v.Name)`" --resource-group `"$($v.RG)`" --query '[].{Subnet:name, Address:addressPrefix}' -o json"
  foreach ($s in $sn) { 
    $subnetRows += [pscustomobject]@{ VNet = $v.Name; Subnet = $s.Subnet; Address = $s.Address }
  }
}

$nsgs = Get-AzJson "az network nsg list --query '[].{Name:name, RG:resourceGroup, Location:location}' -o json"

$kvs = Get-AzJson "az keyvault list --query '[].{Name:name, RG:resourceGroup, Location:location, VaultUri:vaultUri}' -o json"

$stores = Get-AzJson "az storage account list --query '[].{Name:name, RG:resourceGroup, Location:location, Kind:kind, Sku:sku.name}' -o json"

$law = Get-AzJson "az monitor log-analytics workspace list --query '[].{Name:name, RG:resourceGroup, Location:location, Sku:sku}' -o json"

$policyAssignments = Get-AzJson "az policy assignment list --query '[].{Name:name, DisplayName:displayName, Scope:scope, EnforcementMode:enforcementMode}' -o json"

$diag = Get-AzJson "az monitor diagnostic-settings list --resource '/subscriptions/$SubscriptionId' -o json"

# -----------------------------
# Scoring (8 categories x 12.5)
# -----------------------------
$score = 0
$details = @()

function Score-Add {
  param([string]$Name, [bool]$Ok, [string]$Tip)
  $points = $Ok ? 12.5 : 0
  $script:score += $points
  $script:details += [pscustomobject]@{ Area = $Name; Status = ($Ok ? "OK" : "Missing"); Points = $points; Tip = $Tip }
}

Score-Add -Name "Subscription & Login" -Ok ($sub -ne $null) -Tip "Run 'az login' and ensure the correct subscription is selected."
Score-Add -Name "Resource Groups"     -Ok (($rgs | Measure-Object).Count -ge 4) -Tip "Create RGs: rg-preprod-mgmt, rg-preprod-net, rg-preprod-app, rg-preprod-sec."
Score-Add -Name "VNets & Subnets"     -Ok (($vnets | Measure-Object).Count -ge 2 -and ($subnetRows | Measure-Object).Count -ge 3) -Tip "Deploy hub/spoke VNets and app/data/shared subnets."
Score-Add -Name "NSGs"                -Ok (($nsgs | Measure-Object).Count -ge 1) -Tip "Create NSGs and associate to subnets (e.g., app)."
Score-Add -Name "Key Vault"           -Ok (($kvs | Measure-Object).Count -ge 1) -Tip "Deploy Key Vault in security RG; enable RBAC or add access policies."
Score-Add -Name "Storage Accounts"    -Ok (($stores | Measure-Object).Count -ge 1) -Tip "Create a central Storage Account; disable public network access if required."
Score-Add -Name "Policy Assignments"  -Ok (($policyAssignments | Measure-Object).Count -ge 1) -Tip "Assign 'Allowed Locations' and other baseline policies."
Score-Add -Name "Diagnostic Settings" -Ok (($diag | Measure-Object).Count -ge 1) -Tip "Route subscription Activity Logs to Log Analytics."

# -----------------------------
# HTML Render
# -----------------------------
$css = @"
<style>
  :root { --bg:#0b1020; --panel:#121733; --ink:#e7eaf6; --muted:#9aa3c7; --ok:#10B981; --warn:#F59E0B; --err:#EF4444; --accent:#6366F1; }
  body { margin:0; font-family: Segoe UI, system-ui, -apple-system, Roboto, Arial; background:var(--bg); color:var(--ink); }
  header { position:sticky; top:0; background:linear-gradient(90deg, #0f172a, #1e293b); padding:18px 24px; border-bottom:1px solid #223; z-index:10; }
  header h1 { margin:0 0 4px 0; font-size:20px; }
  header .meta { color:var(--muted); font-size:12px; }
  main { padding: 24px; display:grid; gap:18px; }
  section { background:var(--panel); border:1px solid #1c2447; border-radius:14px; padding:16px; }
  h2 { margin:0 0 12px 0; font-size:16px; display:flex; align-items:center; gap:8px; }
  .badge { color:#0b1020; font-weight:600; font-size:11px; padding:3px 8px; border-radius:999px; }
  .grid { display:grid; grid-template-columns: repeat(auto-fit,minmax(280px,1fr)); gap:12px; }
  .card { border:1px solid #1c2447; border-radius:12px; overflow:hidden; background:#0f1430; }
  .card-header { padding:10px 12px; border-bottom:1px solid #1c2447; background:#0e1330; color:#cdd3f8; font-weight:600; font-size:13px; }
  .table-wrap { overflow:auto; }
  table { width:100%; border-collapse:collapse; }
  th, td { padding:10px 12px; border-bottom:1px solid #1c2447; white-space:nowrap; font-size:13px; }
  th { text-align:left; color:#aeb7e1; background:#0e1330; position:sticky; top:0; }
  .empty { color:var(--muted); padding:10px 12px; }
  .score { font-size:36px; font-weight:800; }
  .score.ok { color:var(--ok); } .score.warn { color:var(--warn); } .score.err { color:var(--err); }
  .tips { color:#cbd5f7; font-size:13px; }
  .pill { display:inline-block; padding:2px 8px; border-radius:999px; border:1px solid #2a356b; color:#cfd5ff; font-size:12px; margin-right:6px; }
  footer { color:var(--muted); text-align:center; padding:24px; }
</style>
"@

# Determine overall status
$overallClass = if ($score -ge 87.5) { "ok" } elseif ($score -ge 62.5) { "warn" } else { "err" }

# Summary content
$summaryHtml = @"
<div class='grid'>
  <div class='card'>
    <div class='card-header'>Compliance Score</div>
    <div style='padding:18px'>
      <div class='score $overallClass'>$score%</div>
      <div class='tips' style='margin-top:8px'>Higher is better. Score is calculated across 8 baseline landing zone categories.</div>
    </div>
  </div>
  <div class='card'>
    <div class='card-header'>Subscription</div>
    <div style='padding:14px'>
      <div><span class='pill'>Name: $($sub.name)</span><span class='pill'>ID: $($sub.id)</span></div>
      <div style='margin-top:8px'><span class='pill'>Tenant: $($sub.tenant)</span><span class='pill'>User: $($sub.user)</span></div>
    </div>
  </div>
</div>
"@

# Sections
$secRGs = RenderSection -Title "Resource Groups" `
  -Status ($(if (($rgs | Measure-Object).Count -ge 4) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>Expect to see: <b>rg-preprod-mgmt</b>, <b>rg-preprod-net</b>, <b>rg-preprod-app</b>, <b>rg-preprod-sec</b>.</div>" `
  -BodyHtml (TableHtml -Rows $rgs -Columns @("Name","Location") -Title "Resource Groups")

$secVnets = RenderSection -Title "Virtual Networks & Subnets" `
  -Status ($(if (($vnets | Measure-Object).Count -ge 2 -and ($subnetRows | Measure-Object).Count -ge 3) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>Hub/Spoke topology expected. Hub: 10.0.0.0/16. Spoke: 10.10.0.0/16. Required subnets include app/data/shared.</div>" `
  -BodyHtml ( (TableHtml -Rows $vnets -Columns @("Name","RG","Location","Address") -Title "VNets") + (TableHtml -Rows $subnetRows -Columns @("VNet","Subnet","Address") -Title "Subnets") )

$secNSGs = RenderSection -Title "Network Security Groups" `
  -Status ($(if (($nsgs | Measure-Object).Count -ge 1) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>At least one NSG should be associated to subnets (e.g., spoke app subnet).</div>" `
  -BodyHtml (TableHtml -Rows $nsgs -Columns @("Name","RG","Location") -Title "NSGs")

$secKV = RenderSection -Title "Key Vault" `
  -Status ($(if (($kvs | Measure-Object).Count -ge 1) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>RBAC-enabled Key Vault recommended (Classic access policies optional).</div>" `
  -BodyHtml (TableHtml -Rows $kvs -Columns @("Name","RG","Location","VaultUri") -Title "Key Vaults")

$secSA = RenderSection -Title "Storage Accounts" `
  -Status ($(if (($stores | Measure-Object).Count -ge 1) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>Central storage (e.g., for state, logs, exports). Consider disabling public network access.</div>" `
  -BodyHtml (TableHtml -Rows $stores -Columns @("Name","RG","Location","Kind","Sku") -Title "Storage Accounts")

$secLAW = RenderSection -Title "Log Analytics & Diagnostics" `
  -Status ($(if (($law | Measure-Object).Count -ge 1 -and ($diag | Measure-Object).Count -ge 1) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>Subscription Activity Logs should flow to Log Analytics (Administrative, Security, Policy,...).</div>" `
  -BodyHtml ( (TableHtml -Rows $law -Columns @("Name","RG","Location","Sku") -Title "Log Analytics Workspaces") + (TableHtml -Rows $diag -Columns @("name","id") -Title "Subscription Diagnostic Settings") )

$secPol = RenderSection -Title "Policy Assignments" `
  -Status ($(if (($policyAssignments | Measure-Object).Count -ge 1) {"ok"} else {"warn"})) `
  -SummaryHtml "<div class='tips'>Baseline policies: Allowed Locations, Deny Public IP, Tag inheritance, etc.</div>" `
  -BodyHtml (TableHtml -Rows $policyAssignments -Columns @("Name","DisplayName","Scope","EnforcementMode") -Title "Policy Assignments")

# Remediation tips table
$remRows = $details | Where-Object { $_.Status -eq "Missing" } | ForEach-Object {
  [pscustomobject]@{ Area = $_.Area; Recommendation = $_.Tip }
}
$remHtml = TableHtml -Rows $remRows -Columns @("Area","Recommendation") -Title "Remediation Tips"

# Compose HTML
$html = @"
<!doctype html>
<html lang='en'>
<head>
<meta charset='utf-8' />
<meta name='viewport' content='width=device-width, initial-scale=1' />
<title>Azure Landing Zone Health Report</title>
$css
</head>
<body>
<header>
  <h1>Azure Landing Zone Health Report</h1>
  <div class="meta">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") · Subscription: $($sub.id) · Region focus: $Location</div>
</header>
<main>
  <section>
    $summaryHtml
  </section>
  $secRGs
  $secVnets
  $secNSGs
  $secKV
  $secSA
  $secLAW
  $secPol
  <section>
    <h2>Overall Remediation $([Badge "GUIDE" "warn"])</h2>
    $remHtml
  </section>
</main>
<footer>
  Azure Landing Zone · Automated Report
</footer>
</body>
</html>
"@

# Write and open
$folder = Split-Path -Path $ReportPath -Parent
if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Force -Path $folder | Out-Null }
Set-Content -Path $ReportPath -Value $html -Encoding UTF8
Write-Host "✅ Report generated: $ReportPath" -ForegroundColor Green

# Try open in default browser
try { Start-Process $ReportPath } catch { Write-Host "Open file manually: $ReportPath" -ForegroundColor Yellow }
