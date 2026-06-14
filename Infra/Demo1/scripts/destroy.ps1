[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroup = 'rg-demo1-dev',
    [switch]$Force,
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

$exists = az group exists --name $ResourceGroup -o tsv
if ($exists -ne 'true') {
    Write-Host "Resource group '$ResourceGroup' does not exist. Nothing to delete."
    exit 0
}

Write-Host "Resources in '$ResourceGroup':"
az resource list --resource-group $ResourceGroup --query "[].{Name:name, Type:type}" -o table

if (-not $Force) {
    $confirm = Read-Host "Delete ALL resources in '$ResourceGroup'? Type the resource group name to confirm"
    if ($confirm -ne $ResourceGroup) {
        Write-Host 'Cancelled.'
        exit 0
    }
}

$deleteArgs = @('group', 'delete', '--name', $ResourceGroup, '--yes')
if ($NoWait) { $deleteArgs += '--no-wait' }

Write-Host "Deleting resource group '$ResourceGroup'..."
az @deleteArgs

if ($NoWait) {
    Write-Host "Delete started. Check: az group show --name $ResourceGroup"
}
else {
    Write-Host "Done. '$ResourceGroup' deleted."
}
