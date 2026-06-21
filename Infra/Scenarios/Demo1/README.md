# Demo1 — Hub-spoke with Bastion RDP

A Bicep scenario that deploys a **hub-spoke network** with a **private Windows VM** and **Azure Bastion** for secure admin access.

## What scenario it covers

Demo1 models a common enterprise network pattern:

- A **hub** VNet hosts shared connectivity (Azure Bastion).
- A **spoke** VNet hosts application workloads (a Windows VM).
- **VNet peering** connects hub ↔ spoke.
- The VM has **no public IP** — operators connect via **Bastion RDP** in the browser.

Use this demo to learn private workload placement, NSG rules, and jump-host access without exposing VMs to the internet.

**Not included:** Azure SQL, private endpoints, VPN, or ExpressRoute (kept focused on hub-spoke + Bastion).

## Architecture

```
                    Internet
                        │
                        ▼
              ┌─────────────────────┐
              │  Hub VNet           │
              │  10.0.0.0/16        │
              │  ┌───────────────┐  │
              │  │ AzureBastion  │  │
              │  │ 10.0.1.0/26   │  │
              │  └───────────────┘  │
              └──────────┬──────────┘
                         │ peering
              ┌──────────▼──────────┐
              │  Spoke VNet          │
              │  10.1.0.0/16        │
              │  ┌───────────────┐  │
              │  │ VM (private)  │  │
              │  │ Windows 2022  │  │
              │  │ 10.1.0.0/24   │  │
              │  └───────────────┘  │
              └─────────────────────┘

  Key Vault ── stores vm-admin-password
```

## Resources deployed

| Resource | Bicep module | Purpose |
|----------|--------------|---------|
| Hub VNet | `modules/hub.bicep` | `vnet-hub-demo1-dev` (`10.0.0.0/16`) |
| Bastion subnet | `modules/hub.bicep` | `AzureBastionSubnet` (`10.0.1.0/26`) |
| Spoke VNet | `modules/spoke.bicep` | `vnet-spoke-demo1-dev` (`10.1.0.0/16`) |
| VM subnet + NSG | `modules/spoke.bicep` | `snet-vm`; RDP 3389 from Bastion only |
| VNet peering | `modules/peering.bicep` | Hub ↔ spoke |
| Azure Bastion | `modules/bastion.bicep` | Basic SKU, browser RDP |
| Windows VM | `modules/vm.bicep` | Server 2022, `Standard_B2ms`, no public IP |
| Key Vault | `modules/keyvault.bicep` | Secret `vm-admin-password` |

## File layout

```
Demo1/
├── main.bicep
├── main.dev.bicepparam
├── modules/
│   ├── hub.bicep
│   ├── spoke.bicep
│   ├── peering.bicep
│   ├── bastion.bicep
│   ├── vm.bicep
│   └── keyvault.bicep
├── scripts/
│   ├── deploy.ps1
│   └── destroy.ps1
├── secrets.local.ps1.example
└── README.md
```

**Gitignored:** `secrets.local.ps1`, `main.json`

## Bicep concepts practiced

- Multi-module orchestration from a root `main.bicep`
- Subnet naming rules (`AzureBastionSubnet` must be exact)
- NSG inbound rules scoped to the Bastion source subnet
- `@secure()` parameters and Key Vault secret storage
- `uniqueString()` for globally unique resource names
- Module outputs passed between modules (e.g. `bastionSubnetId`, `vmSubnetId`)

## Deploy locally

### Prerequisites

- Azure CLI (`az login`)
- PowerShell

### Steps

```powershell
cd Infra/Scenarios/Demo1

Copy-Item secrets.local.ps1.example secrets.local.ps1
# Edit secrets.local.ps1 — set $vmAdminPassword

./scripts/deploy.ps1 -WhatIf   # optional preview
./scripts/deploy.ps1
```

| Setting | Default |
|---------|---------|
| Resource group | `rg-demo1-dev` |
| Location | `australiaeast` |
| Parameters file | `main.dev.bicepparam` |
| VM username | `azureuser` |

### Manual deploy

```powershell
. .\secrets.local.ps1

az group create --name rg-demo1-dev --location australiaeast

az deployment group create `
  --resource-group rg-demo1-dev `
  --template-file main.bicep `
  --parameters main.dev.bicepparam `
  --parameters vmAdminPassword="$vmAdminPassword"
```

## Connect to the VM

1. Azure Portal → Virtual Machine → **Connect** → **Bastion**
2. Username: `azureuser`
3. Password:

```powershell
az keyvault secret show `
  --vault-name <keyVaultName-from-output> `
  --name vm-admin-password `
  --query value -o tsv
```

The VM can reach the internet via Azure SNAT (outbound only). Inbound traffic is blocked except RDP from Bastion.

## Destroy

```powershell
./scripts/destroy.ps1
# or: az group delete --name rg-demo1-dev --yes
```

## GitHub Actions

Workflow: [`.github/workflows/demo1-infra.yml`](../../../.github/workflows/demo1-infra.yml) — **manual only** (`workflow_dispatch`).

| Secret | Purpose |
|--------|---------|
| `AZURE_CLIENT_ID` | OIDC login |
| `AZURE_TENANT_ID` | OIDC login |
| `AZURE_SUBSCRIPTION_ID` | OIDC login |
| `DEMO1_VM_ADMIN_PASSWORD` | VM admin password |

Run from **Actions** → **Demo1 Hub-Spoke - Infra** → **Run workflow**.

## Environments

Supported in Bicep: `dev`, `test`, `prod`. To add another environment:

1. Create `main.<env>.bicepparam`
2. Deploy to `rg-demo1-<env>`
3. Add a GitHub environment with its own `DEMO1_VM_ADMIN_PASSWORD` secret

## Related scenarios

| Scenario | Focus |
|----------|-------|
| [Demo2](../Demo2/README.md) | Azure SQL free tier |
| [Infra overview](../../README.md) | All scenarios index |
