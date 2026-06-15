using './main.bicep'

// Committed config only.
// SQL password: secrets.local.ps1 or --parameters sqlAdminPassword='...'
// Client IP: deploy.ps1 auto-detects public IP, or --parameters clientIpAddress='x.x.x.x'

param environment = 'dev'
param location = 'australiaeast'
param namePrefix = 'demo2'
param sqlAdminLogin = 'sqladmin'
param databaseName = 'appdb'
param useFreeLimit = true

param tags = {
  project: 'demo2-sql-free'
  environment: 'dev'
}
