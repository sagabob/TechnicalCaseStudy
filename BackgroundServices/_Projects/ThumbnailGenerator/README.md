# Image Upload Service

Web app that uploads images to Azure Blob Storage, with Bicep infra and a GitHub Actions deploy pipeline.

## Project layout

```
ThumbnailGenerator/
├── README.md
├── infra/                          # Step 1: storage account + uploads container
│   ├── main.bicep
│   ├── main.dev.bicepparam
│   └── modules/storage.bicep
└── WebAppSln/TdpImageApp/          # ASP.NET Core MVC upload UI
    ├── Controllers/UploadController.cs
    ├── Services/BlobImageStorageService.cs
    └── Views/Upload/Index.cshtml
```

## Run the web app locally

### 1. Configure local settings

Copy the example file and fill in your values. **`appsettings.Development.json` is gitignored** — it stays on your machine only.

```powershell
cd WebAppSln/TdpImageApp
copy appsettings.Development.example.json appsettings.Development.json
```

Edit `appsettings.Development.json`:

```json
{
  "BlobStorage": {
    "ServiceUri": "https://<storageAccountName>.blob.core.windows.net",
    "UploadsContainer": "uploads"
  },
  "AZURE_TENANT_ID": "<tenant-id>",
  "AZURE_CLIENT_ID": "<client-id>",
  "AZURE_CLIENT_SECRET": "<client-secret>"
}
```

**Option A — Azure CLI:** remove the three `AZURE_*` entries and run `az login`. The app falls back to `DefaultAzureCredential`.

**Option B — Service principal:** keep `AZURE_*` filled in. `Program.cs` builds a `ClientSecretCredential` from configuration.

The identity needs **Storage Blob Data Contributor** on the storage account.

```powershell
dotnet run
```

Open the app URL and upload an image. Files land in the `uploads` container.

## Infrastructure (Step 1)

Deploys:

- Storage account
- Blob container `uploads` (source images)
- Blob container `thumbnails` (generated thumbnails)

```powershell
az group create --name rg-tcs-thumb-dev --location australiaeast

az deployment group create `
  --resource-group rg-tcs-thumb-dev `
  --template-file infra/main.bicep `
  --parameters infra/main.dev.bicepparam
```

## CI/CD

### Infrastructure

Workflow: [`.github/workflows/thumbnail-generator-infra.yml`](../../../.github/workflows/thumbnail-generator-infra.yml)

Deploys infra to `rg-tcs-thumb-dev` in `australiaeast` on push to `main` or manual run.

GitHub secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (+ federated credential for `environment:dev`).

### Docker image (public Docker Hub repository)

Workflow: [`.github/workflows/thumbnail-generator-docker.yml`](../../../.github/workflows/thumbnail-generator-docker.yml)

Builds `WebAppSln/TdpImageApp` and pushes to a **public** Docker Hub repository on push to `main` (app changes) or manual run.

Create the repository on Docker Hub first (`tdp-image-app`, visibility **Public**). GitHub Actions only pushes images; it does not create the repo.

| GitHub secret | Value |
|---------------|--------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token with **Read & Write** ([create here](https://hub.docker.com/settings/security)) |

Secrets are used only by CI to **push**. Anyone can **pull** without logging in:

```powershell
docker pull <username>/tdp-image-app:latest
docker run -p 8080:8080 -e BlobStorage__ServiceUri=... <username>/tdp-image-app:latest
```

Tags pushed:

- `<username>/tdp-image-app:latest`
- `<username>/tdp-image-app:<git-sha>`

Run locally:

```powershell
cd WebAppSln/TdpImageApp
docker build -t tdp-image-app .
docker run -p 8080:8080 --env-file .env tdp-image-app
```

(`appsettings.Development.json` is not in the image — pass env vars or mount config at run time.)

## Next steps (later)

- Service Bus for async processing
- App Service to host the web app in Azure
- Managed identity instead of local `az login`
