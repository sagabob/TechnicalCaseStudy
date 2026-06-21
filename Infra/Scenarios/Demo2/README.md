# Demo2 — Azure SQL free offer

A Bicep scenario that deploys **Azure SQL Database** on the **free offer**, with **Key Vault** for secrets and **SQL firewall** rules for Azure services and your PC.

## What scenario it covers

Demo2 is a minimal **PaaS database** stack for dev/test:

- **Azure SQL Database** — serverless General Purpose with `useFreeLimit: true`
- **Key Vault** — stores the SQL admin password
- **SQL firewall** — `AllowAzureServices` plus optional `AllowClientIp` (auto-detected on deploy)

Unlike [Demo1](../Demo1/README.md), there is no VNet or VM. SQL uses a **public endpoint** restricted by firewall rules. Good for learning database deployment, multi-environment parameters, and connecting from SSMS on your PC.

## Architecture

```
  Your PC (SSMS) ──► SQL firewall (AllowClientIp)
                           │
                           ▼
              ┌────────────────────────┐
              │  SQL Server (public)   │
              │  sql-demo2-dev-*       │
              │  ┌──────────────────┐  │
              │  │ appdb (free tier)  │  │
              │  │ GP_S_Gen5_1        │  │
              │  │ useFreeLimit       │  │
              │  └──────────────────┘  │
              └────────────────────────┘

  Key Vault ── stores sql-admin-password
  AllowAzureServices (0.0.0.0) ── other Azure PaaS apps
```

## Resources deployed

| Resource | Bicep module | Purpose |
|----------|--------------|---------|
| SQL Server | `modules/sql.bicep` | Logical server, TLS 1.2, public access |
| SQL Database | `modules/sql.bicep` | `appdb` on free offer, auto-pause |
| Firewall `AllowAzureServices` | `modules/sql.bicep` | Azure PaaS connectivity (`0.0.0.0` sentinel) |
| Firewall `AllowClientIp` | `modules/sql.bicep` | Your PC public IP (when provided) |
| Key Vault | `modules/keyvault.bicep` | Secret `sql-admin-password` |

## Free offer limits

- **100,000** vCore-seconds / month per database
- **32 GB** data + **32 GB** backup
- Up to **10** free databases per subscription
- Auto-pause when limits are exceeded (`freeLimitExhaustionBehavior: AutoPause`)

Set `useFreeLimit = false` in the bicepparam file if the subscription limit is reached.

## File layout

```
Demo2/
├── main.bicep
├── main.dev.bicepparam
├── main.stage.bicepparam
├── modules/
│   ├── sql.bicep
│   └── keyvault.bicep
├── scripts/
│   ├── deploy.ps1
│   └── destroy.ps1
├── secrets.local.ps1.example
├── secrets.stage.local.ps1.example
├── README.md
└── docs/
    └── deployment.md          # Detailed Bicep walkthrough
```

**Gitignored:** `secrets.local.ps1`, `secrets.*.local.ps1`, `main.json`

## Bicep concepts practiced

- Conditional resources (`if (!empty(clientIpAddress))` for firewall rule)
- SQL API `@2023-08-01` for `useFreeLimit`
- Environment-specific `.bicepparam` files (`dev`, `stage`)
- `-Environment` switch in `deploy.ps1`
- Separating committed config from secrets

See [docs/deployment.md](docs/deployment.md) for a full Bicep learning guide.

## Deploy locally

### Prerequisites

- Azure CLI (`az login`)
- PowerShell

### Dev

```powershell
cd Infra/Scenarios/Demo2

Copy-Item secrets.local.ps1.example secrets.local.ps1
# Edit $sqlAdminPassword

./scripts/deploy.ps1 -WhatIf   # optional preview
./scripts/deploy.ps1
```

### Stage

```powershell
Copy-Item secrets.stage.local.ps1.example secrets.stage.local.ps1
./scripts/deploy.ps1 -Environment stage
```

| | Dev | Stage |
|---|-----|-------|
| Resource group | `rg-demo2-dev` | `rg-demo2-stage` |
| Parameters | `main.dev.bicepparam` | `main.stage.bicepparam` |
| Secrets file | `secrets.local.ps1` | `secrets.stage.local.ps1` |

`deploy.ps1` auto-detects your public IP for the SQL firewall unless you pass `-SkipClientIp` or set `$clientIpAddress` in the secrets file.

## Connect to the database

| Setting | Value |
|---------|-------|
| Server | `sqlServerFqdn` (deployment output) |
| Database | `appdb` |
| Login | `sqladmin` |
| Password | Key Vault secret `sql-admin-password` |

```powershell
az keyvault secret show `
  --vault-name <keyVaultName> `
  --name sql-admin-password `
  --query value -o tsv

sqlcmd -S <sqlServerFqdn> -d appdb -U sqladmin -P "<password>" -Q "SELECT 1"
```

## Destroy

```powershell
./scripts/destroy.ps1
./scripts/destroy.ps1 -Environment stage
```

## GitHub Actions

Workflow: [`.github/workflows/demo2-infra.yml`](../../../.github/workflows/demo2-infra.yml) — **manual only** (`workflow_dispatch`).

Run from **Actions** → **Demo2 SQL Free - Infra** → pick **dev** or **stage**.

| Secret | Required | Purpose |
|--------|----------|---------|
| `AZURE_CLIENT_ID` | Yes | OIDC login |
| `AZURE_TENANT_ID` | Yes | OIDC login |
| `AZURE_SUBSCRIPTION_ID` | Yes | OIDC login |
| `DEMO2_SQL_ADMIN_PASSWORD` | Yes | SQL admin password |
| `DEMO2_CLIENT_IP` | No | Your PC IP for `AllowClientIp` |

Configure per GitHub environment (`dev` / `stage`) for different passwords.

## Related scenarios

| Scenario | Focus |
|----------|-------|
| [Demo1](../Demo1/README.md) | Hub-spoke networking + Bastion RDP |
| [Infra overview](../../README.md) | All scenarios index |
| [deployment.md](docs/deployment.md) | Deep Bicep deployment guide |
