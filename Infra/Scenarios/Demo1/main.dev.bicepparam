using './main.bicep'

// Committed config only. VM password: secrets.local.ps1 or --parameters vmAdminPassword='...'

param environment = 'dev'
param location = 'australiaeast'
param namePrefix = 'demo1'
param vmAdminUsername = 'azureuser'

param tags = {
  project: 'demo1-hub-spoke'
  environment: 'dev'
}
