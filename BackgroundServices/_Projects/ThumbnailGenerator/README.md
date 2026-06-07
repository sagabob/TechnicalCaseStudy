# Thumbnail Generator — Infrastructure (step by step)

Infrastructure will be built incrementally in Bicep under `infra/`.

## Recommended order

| Step | What | Why start here |
|------|------|----------------|
| **1** | **Storage account + blob containers** | Simplest resource; core to thumbnails (`uploads`, `thumbnails`); no VNet or identity yet |
| 2 | Service Bus namespace + queue | Adds async messaging; still standalone |
| 3 | App Service Plan + Web App (code deploy) | Host the API; connect to storage + queue with connection strings first |
| 4 | Managed identity + RBAC | Replace connection strings with `DefaultAzureCredential` |
| 5 | Azure Container Registry + Docker on App Service | Containerize the app; pull from ACR |
| 6 | VNet + subnets | Network foundation |
| 7 | Private endpoints + disable public access | Lock down storage and Service Bus |
| 8 | VNet integration on App Service | App reaches private endpoints through the VNet |

Each step should deploy on its own, be testable, and add one concept.

## Step 1 — start here

**Storage account** with two blob containers:

- `uploads` — source images
- `thumbnails` — generated output

Files to create:

```
infra/
├── main.bicep              # entry point
├── main.dev.bicepparam     # dev parameters
└── modules/
    └── storage.bicep       # storage account + containers
```

Deploy to an existing resource group:

```powershell
az group create --name rg-tcs-thumb-dev --location australiaeast

az deployment group create `
  --resource-group rg-tcs-thumb-dev `
  --template-file infra/main.bicep `
  --parameters infra/main.dev.bicepparam
```

Verify in the portal or CLI:

```powershell
az storage container list --account-name <storageAccountName> --auth-mode login
```

## Current status

**Step 1 complete** — storage account + `uploads` and `thumbnails` blob containers.

Next: **Step 2 — Service Bus namespace + queue**.

## CI/CD pipeline

GitHub Actions workflow: [`.github/workflows/thumbnail-generator-infra.yml`](../../../.github/workflows/thumbnail-generator-infra.yml)

| Trigger | Behavior |
|---------|----------|
| Push to `main` (infra changes) | What-if, deploy to dev |
| Manual (`workflow_dispatch`) | What-if, deploy to dev |

Default deploy target:

- Resource group: `rg-tcs-thumb-dev`
- Region: `australiaeast`
- Parameters: `infra/main.dev.bicepparam`

### One-time Azure setup (OIDC)

1. Create an app registration (or use an existing one) in Microsoft Entra ID.
2. Add a **federated credential** for GitHub Actions:
   - Entity type: GitHub Actions
   - Organization / repo: your GitHub org and this repository
   - Subject: `repo:<org>/<repo>:environment:dev` (matches the workflow `environment: dev`)
3. Assign **Contributor** on the subscription or resource group to the app registration.
4. Add GitHub repository secrets:

| Secret | Value |
|--------|--------|
| `AZURE_CLIENT_ID` | App registration client ID |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |

5. Create a GitHub **environment** named `dev` (Settings → Environments) if you want deployment protection rules.

### Run manually

Actions → **Thumbnail Generator - Infra** → **Run workflow**.
