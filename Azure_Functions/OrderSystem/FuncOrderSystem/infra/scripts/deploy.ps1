[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-func-order-dev',
    [string]$Location = 'australiaeast',
    [string]$DeploymentName = "func-order-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$infraRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $infraRoot
try {
    Write-Host "Ensuring resource group '$ResourceGroup' in $Location..."
    az group create --name $ResourceGroup --location $Location --output none

    $deployArgs = @(
        '--resource-group', $ResourceGroup,
        '--template-file', 'main.bicep',
        '--parameters', 'main.dev.bicepparam'
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
        Write-Host "Service Bus: $($outputs.serviceBusFqdn.value)"
        Write-Host "Queue:       $($outputs.queueName.value)"
        Write-Host ""
        Write-Host "Copy connection string to order-api-func/local.settings.json:"
        Write-Host "  SERVICE_BUS_CONNECTION_STRING = (see secure output above)"
        Write-Host "  QUEUE_NAME = $($outputs.queueName.value)"
        Write-Host ""
        Write-Host "Connection string:"
        Write-Host "  az deployment group show -g $ResourceGroup -n $DeploymentName --query properties.outputs.serviceBusConnectionString.value -o tsv"
    }
}
finally {
    Pop-Location
}
