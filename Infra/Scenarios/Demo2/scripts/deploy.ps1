[CmdletBinding()]
param(
    [ValidateSet('dev', 'test', 'stage', 'prod')]
    [string]$Environment = 'dev',
    [string]$ResourceGroup,
    [string]$Location = 'australiaeast',
    [string]$DeploymentName,
    [string]$ClientIpAddress,
    [switch]$SkipClientIp,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$infraRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if (-not $PSBoundParameters.ContainsKey('ResourceGroup')) {
    $ResourceGroup = "rg-demo2-$Environment"
}
if (-not $PSBoundParameters.ContainsKey('DeploymentName')) {
    $DeploymentName = "demo2-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

$bicepParamFile = "main.$Environment.bicepparam"

Push-Location $infraRoot
try {
    if (-not (Test-Path $bicepParamFile)) {
        throw "Parameter file not found: $bicepParamFile"
    }

    $secretsFile = Join-Path $infraRoot "secrets.$Environment.local.ps1"
    if (-not (Test-Path $secretsFile)) {
        $secretsFile = Join-Path $infraRoot 'secrets.local.ps1'
    }
    if (-not (Test-Path $secretsFile)) {
        throw @"
Secrets file not found.

Create one of:
  secrets.$Environment.local.ps1  (recommended for $Environment)
  secrets.local.ps1

Copy from secrets.local.ps1.example or secrets.stage.local.ps1.example
"@
    }

    . $secretsFile
    if ([string]::IsNullOrWhiteSpace($sqlAdminPassword)) {
        throw 'sqlAdminPassword is not set in the secrets file'
    }

    $resolvedClientIp = ''
    if ($SkipClientIp) {
        Write-Host 'Skipping client IP firewall rule (-SkipClientIp).'
    }
    elseif ($PSBoundParameters.ContainsKey('ClientIpAddress')) {
        $resolvedClientIp = $ClientIpAddress
        if ([string]::IsNullOrWhiteSpace($resolvedClientIp)) {
            Write-Host 'ClientIpAddress parameter is empty — skipping client IP firewall rule.'
        }
        else {
            Write-Host "Using client IP from parameter: $resolvedClientIp"
        }
    }
    elseif ((Get-Content -LiteralPath $secretsFile -Raw) -match '(?m)^\s*\$clientIpAddress\s*=') {
        $resolvedClientIp = $clientIpAddress
        if ([string]::IsNullOrWhiteSpace($resolvedClientIp)) {
            Write-Host 'clientIpAddress is empty in secrets file — skipping client IP firewall rule.'
        }
        else {
            Write-Host "Using client IP from secrets file: $resolvedClientIp"
        }
    }
    else {
        Write-Host 'Detecting public IP for SQL firewall...'
        $resolvedClientIp = Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 15
        Write-Host "Detected public IP: $resolvedClientIp"
    }

    Write-Host "Environment:     $Environment"
    Write-Host "Resource group:    $ResourceGroup"
    Write-Host "Parameters file:   $bicepParamFile"
    Write-Host "Ensuring resource group '$ResourceGroup' in $Location..."
    az group create --name $ResourceGroup --location $Location --output none

    $deployArgs = @(
        '--resource-group', $ResourceGroup,
        '--template-file', 'main.bicep',
        '--parameters', $bicepParamFile,
        '--parameters', "sqlAdminPassword=$sqlAdminPassword"
    )

    if (-not [string]::IsNullOrWhiteSpace($resolvedClientIp)) {
        $deployArgs += '--parameters', "clientIpAddress=$resolvedClientIp"
    }

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
        Write-Host "SQL server: $($outputs.sqlServerFqdn.value)"
        Write-Host "Database:   $($outputs.sqlDatabaseName.value) (free offer: useFreeLimit=true)"
        Write-Host "Login:      $($outputs.sqlAdminLogin.value)"
        if ($outputs.clientIpAddress.value) {
            Write-Host "Client IP:  $($outputs.clientIpAddress.value) (firewall rule AllowClientIp)"
        }
        Write-Host "Password:   az keyvault secret show --vault-name $($outputs.keyVaultName.value) --name sql-admin-password --query value -o tsv"
        Write-Host ('Test:       sqlcmd -S {0} -d {1} -U {2} -P "<password>" -Q "SELECT 1"' -f $outputs.sqlServerFqdn.value, $outputs.sqlDatabaseName.value, $outputs.sqlAdminLogin.value)
    }
}
finally {
    Pop-Location
}
