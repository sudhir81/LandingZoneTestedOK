<#
.SYNOPSIS
  Azure Landing Zone Audit Report (Verbose & Enhanced)

.DESCRIPTION
  Checks core components of your Azure Landing Zone, including management groups,
  networking, monitoring, policy, security, and compliance. Generates an HTML report
  with scores and recommendations.

.AUTHOR
  GPT-Audit (Final Version, Oct 2025)
#>

# --- Global Variables ---
$subscriptionId = (az account show --query id -o tsv --verbose)
$tenantId = (az account show --query tenantId -o tsv --verbose)
$reportFile = "LandingZone-Report.html"

$script:score = 0
$script:details = @()

# --- Helper: Safe JSON execution ---
function Safe-Json($cmd) {
  try {
    Write-Host " Running: $cmd" -ForegroundColor Yellow
    $raw = Invoke-Expression $cmd
    if ($raw -match "^{|^\[") { return $raw | ConvertFrom-Json }
    else {
      Write-Host " Command did not return valid JSON. Skipping..." -ForegroundColor DarkYellow
      return @()
    }
  }
  catch {
    Write-Host " Failed to run command: $cmd" -ForegroundColor Red
    return @()
  }
}

# --- Helper: Scoring ---
function Score-Add {
  param([string]$Name, [bool]$Ok, [string]$Tip)
  $points = if ($Ok) { 12.5 } else { 0 }
  $status = if ($Ok) { "OK" } else { "Missing" }
  $script:score += $points
  $script:details += [pscustomobject]@{
    Area   = $Name
    Status = $status
    Points = $points
    Tip    = $Tip
  }
  if ($Ok) { Write-Host " ✅ $Name - OK ($points points)" -ForegroundColor Green }
  else     { Write-Host " ❌ $Name - Missing ($points points)" -ForegroundColor Red }
}

Write-Host "🔍 Checking Azure Landing Zone components..." -ForegroundColor Cyan

# 1. Management Groups
$mg = Safe-Json "az account management-group list -o json --verbose"
Score-Add "Management Groups" ($mg.Count -gt 0) "Create a standard MG hierarchy: platform, landingzones, corp."

# 2. Resource Groups
$rg = Safe-Json "az group list -o json --verbose"
Score-Add "Resource Groups" ($rg.Count -gt 3) "Ensure mgmt, network, security, and workload RGs exist."

# 3. Virtual Networks
$vnet = Safe-Json "az network vnet list -o json --verbose"
Score-Add "Networking (VNets)" ($vnet.Count -ge 2) "Create hub and spoke VNets."

# 4. Log Analytics Workspace
$law = Safe-Json "az monitor log-analytics workspace list -o json --verbose"
Score-Add "Monitoring (Log Analytics)" ($law.Count -gt 0) "Deploy a central Log Analytics Workspace."

# 5. Key Vault
$kv = Safe-Json "az keyvault list -o json --verbose"
Score-Add "Key Vault" ($kv.Count -gt 0) "Deploy a shared Key Vault for secrets management."

# 6. Policy Assignments
$policy = Safe-Json "az policy assignment list -o json --verbose"
Score-Add "Policy Assignments" ($policy.Count -gt 0) "Assign baseline policies (allowed locations, deny public IP, etc.)"

# 7. Activity Logs Diagnostic Settings (FIXED ✅)
$diag = Safe-Json "az monitor diagnostic-settings list --resource-id \"/subscriptions/$subscriptionId\" -o json --verbose"
Score-Add "Activity Log Diagnostics" ($diag.Count -gt 0) "Enable diagnostic settings to send activity logs to Log Analytics."

# 8. Bastion / Secure Access
$bastion = Safe-Json "az network bastion list -o json --verbose"
Score-Add "Secure Access (Bastion)" ($bastion.Count -gt 0) "Deploy Azure Bastion for secure VM access."

# 9. Defender for Cloud (Bonus)
$defender = Safe-Json "az security pricing list -o json --verbose"
$defenderEnabled = ($defender | Where-Object { $_.pricingTier -eq "Standard" }).Count -gt 0
Score-Add "Defender for Cloud" $defenderEnabled "Enable Microsoft Defender for Cloud to strengthen security posture."

# 10. Policy Compliance Score (Bonus)
$compliance = Safe-Json "az policy state summarize -o json --verbose"
$compliantPercent = [math]::Round(($compliance.summary.compliantResources / $compliance.summary.totalResources) * 100, 2)
$policyOk = $compliantPercent -ge 80
Score-Add "Policy Compliance" $policyOk "Improve compliance by remediating non-compliant resources."

# --- Final Score ---
$totalScore = $script:score
if ($totalScore -ge 90) { $grade = "🌟 Excellent" }
elseif ($totalScore -ge 70) { $grade = "✅ Good" }
elseif ($totalScore -ge 50) { $grade = "⚠️ Needs Improvement" }
else { $grade = "🚨 Critical" }

# --- HTML Report ---
$html = @"
<html>
<head>
<title>Azure Landing Zone Audit Report</title>
<style>
  body { font-family:Segoe UI, sans-serif; margin:40px; background:#f4f4f4; }
  h1 { color:#0078D4; }
  table { border-collapse: collapse; width:100%; margin-top:20px; }
  th, td { border:1px solid #ccc; padding:10px; text-align:left; }
  th { background:#0078D4; color:white; }
  .ok { background-color:#c8e6c9; }
  .missing { background-color:#ffcdd2; }
</style>
</head>
<body>
  <h1>🌐 Azure Landing Zone Readiness Report</h1>
  <p><strong>Subscription:</strong> $subscriptionId</p>
  <p><strong>Tenant:</strong> $tenantId</p>
  <p><strong>Date:</strong> $(Get-Date)</p>

  <h2>✅ Overall Score: $totalScore / 125 — $grade</h2>

  <table>
    <tr>
      <th>Area</th>
      <th>Status</th>
      <th>Points</th>
      <th>Remediation Tip</th>
    </tr>
"@

foreach ($d in $script:details) {
  $cls = if ($d.Status -eq "OK") { "ok" } else { "missing" }
  $html += "<tr class='$cls'><td>$($d.Area)</td><td>$($d.Status)</td><td>$($d.Points)</td><td>$($d.Tip)</td></tr>`n"
}

$html += @"
  </table>

  <h2>📊 Recommendations</h2>
  <ul>
    <li>Review all missing components and deploy them via Terraform or Bicep.</li>
    <li>Remediate non-compliant resources to improve your compliance score.</li>
    <li>Enable Defender for Cloud for advanced threat protection.</li>
    <li>Ensure diagnostic settings and policy baselines are consistently applied.</li>
  </ul>
</body>
</html>
"@

$html | Out-File -FilePath $reportFile -Encoding utf8
Write-Host "✅ Landing Zone audit complete. Open '$reportFile' in your browser to view the report." -ForegroundColor Green
