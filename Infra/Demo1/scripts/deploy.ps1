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
    if (-not (Test-Path 'secrets.bicepparam')) {
        throw @"
secrets.bicepparam not found.

Copy the example and set your passwords:
  Copy-Item secrets.bicepparam.example secrets.bicepparam
"@
    }

    Write-Host "Ensuring resource group '$ResourceGroup' in $Location..."
    az group create --name $ResourceGroup --location $Location --output none

    $deployArgs = @(
        '--resource-group', $ResourceGroup,
        '--template-file', 'main.bicep',
        '--parameters', 'secrets.bicepparam'
    )

    if ($WhatIf) {
        Write-Host 'Running what-if...'
        az deployment group what-if @deployArgs
    }
    else {
        Write-Host "Deploying '$DeploymentName'..."
        az deployment group create --name $DeploymentName @deployArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed. Check the Azure portal or run: az deployment group show --resource-group $ResourceGroup --name $DeploymentName"
        }

        $outputs = az deployment group show `
            --resource-group $ResourceGroup `
            --name $DeploymentName `
            --query properties.outputs `
            -o json | ConvertFrom-Json

        $outputs | ConvertTo-Json -Depth 5
        Write-Host ""
        Write-Host "VM password stored in Key Vault: $($outputs.keyVaultName.value)"
        Write-Host "  VM login ($($outputs.vmAdminUsername.value)): az keyvault secret show --vault-name $($outputs.keyVaultName.value) --name vm-admin-password --query value -o tsv"
    }
}
finally {
    Pop-Location
}
