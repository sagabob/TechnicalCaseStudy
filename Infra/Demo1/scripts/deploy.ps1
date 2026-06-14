[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-demo1-dev',
    [string]$Location = 'australiaeast',
    [string]$DeploymentName = "demo1-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$infraRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $infraRoot
try {
    $secretsFile = Join-Path $infraRoot 'secrets.local.ps1'
    if (-not (Test-Path $secretsFile)) {
        throw @"
secrets.local.ps1 not found.

Copy the example and set your password:
  Copy-Item secrets.local.ps1.example secrets.local.ps1
"@
    }

    . $secretsFile
    if ([string]::IsNullOrWhiteSpace($vmAdminPassword)) {
        throw 'vmAdminPassword is not set in secrets.local.ps1'
    }

    Write-Host "Ensuring resource group '$ResourceGroup' in $Location..."
    az group create --name $ResourceGroup --location $Location --output none

    $deployArgs = @(
        '--resource-group', $ResourceGroup,
        '--template-file', 'main.bicep',
        '--parameters', 'main.dev.bicepparam',
        '--parameters', "vmAdminPassword=$vmAdminPassword"
    )

    if ($WhatIf) {
        Write-Host 'Running what-if...'
        az deployment group what-if @deployArgs
    }
    else {
        Write-Host "Deploying '$DeploymentName'..."
        az deployment group create --name $DeploymentName @deployArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed. Check: az deployment group show --resource-group $ResourceGroup --name $DeploymentName"
        }

        $outputs = az deployment group show `
            --resource-group $ResourceGroup `
            --name $DeploymentName `
            --query properties.outputs `
            -o json | ConvertFrom-Json

        $outputs | ConvertTo-Json -Depth 5
        Write-Host ""
        Write-Host "VM password in Key Vault: $($outputs.keyVaultName.value)"
        Write-Host "  RDP via Bastion -> $($outputs.vmName.value)"
        Write-Host "  Username: $($outputs.vmAdminUsername.value)"
        Write-Host "  Password: az keyvault secret show --vault-name $($outputs.keyVaultName.value) --name vm-admin-password --query value -o tsv"
    }
}
finally {
    Pop-Location
}
