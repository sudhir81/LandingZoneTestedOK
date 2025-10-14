# ================================================
# Azure Landing Zone Health Check Script
# ================================================

# Set variables
$subscriptionId = "4c13f2a5-9a74-4ad1-b6a6-f99adc18cb3b"
$reportPath = "C:\tmp\LandingZone_Report.txt"

# Ensure you are logged in
Write-Host "🔐 Checking Azure CLI login..." -ForegroundColor Cyan
az account show > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Not logged in. Logging in..." -ForegroundColor Yellow
    az login | Out-Null
}

# Set subscription
Write-Host "📁 Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId

"==========================" | Out-File $reportPath
"AZURE LANDING ZONE HEALTH REPORT" | Out-File $reportPath -Append
"Generated: $(Get-Date)" | Out-File $reportPath -Append
"==========================" | Out-File $reportPath -Append

# ---------------------------
# 1. Subscription Details
# ---------------------------
Write-Host "`n🔎 Checking subscription details..."
$subInfo = az account show --query "{name:name, id:id, tenant:tenantId}" -o table
$subInfo | Out-File $reportPath -Append
$subInfo

# ---------------------------
# 2. Resource Groups
# ---------------------------
Write-Host "`n📁 Checking resource groups..."
$rgList = az group list --query "[].{Name:name, Location:location, ProvisioningState:properties.provisioningState}" -o table
$rgList | Out-File $reportPath -Append
$rgList

# ---------------------------
# 3. Virtual Networks & Subnets
# ---------------------------
Write-Host "`n🌐 Checking VNets and Subnets..."
$vnetList = az network vnet list --query "[].{Name:name, RG:resourceGroup, Location:location, Address:addressSpace.addressPrefixes}" -o table
$vnetList | Out-File $reportPath -Append
$vnetList

# ---------------------------
# 4. Network Security Groups
# ---------------------------
Write-Host "`n🛡️ Checking NSGs..."
$nsgList = az network nsg list --query "[].{Name:name, RG:resourceGroup, Location:location}" -o table
$nsgList | Out-File $reportPath -Append
$nsgList

# ---------------------------
# 5. Key Vaults
# ---------------------------
Write-Host "`n🔑 Checking Key Vaults..."
$kvList = az keyvault list --query "[].{Name:name, RG:resourceGroup, Location:location}" -o table
$kvList | Out-File $reportPath -Append
$kvList

# ---------------------------
# 6. Storage Accounts
# ---------------------------
Write-Host "`n📦 Checking Storage Accounts..."
$saList = az storage account list --query "[].{Name:name, RG:resourceGroup, Location:location, Kind:kind}" -o table
$saList | Out-File $reportPath -Append
$saList

# ---------------------------
# 7. Policy Assignments
# ---------------------------
Write-Host "`n📜 Checking Policy Assignments..."
$policyAssignments = az policy assignment list --query "[].{Name:name, DisplayName:displayName, Scope:scope, EnforcementMode:enforcementMode}" -o table
$policyAssignments | Out-File $reportPath -Append
$policyAssignments

# ---------------------------
# 8. Diagnostic Settings
# ---------------------------
Write-Host "`n📊 Checking Diagnostic Settings..."
$diagSettings = az monitor diagnostic-settings list --resource "/subscriptions/$subscriptionId" -o table
$diagSettings | Out-File $reportPath -Append
$diagSettings

# ---------------------------
# 9. Final Summary
# ---------------------------
Write-Host "`n✅ Health check completed!" -ForegroundColor Green
Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Cyan
