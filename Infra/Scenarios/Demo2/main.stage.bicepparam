using './main.bicep'

// Stage environment — committed config only.
// Password: secrets.stage.local.ps1 (or secrets.local.ps1)
// Client IP: deploy.ps1 auto-detects public IP

param environment = 'stage'
param location = 'australiaeast'
param namePrefix = 'demo2'
param sqlAdminLogin = 'sqladmin'
param databaseName = 'appdb'
param useFreeLimit = true

param tags = {
  project: 'demo2-sql-free'
  environment: 'stage'
}
