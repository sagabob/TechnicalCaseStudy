targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name (dev, test, stage, prod).')
@allowed([
  'dev'
  'test'
  'stage'
  'prod'
])
param environment string = 'dev'

@description('Short prefix used in resource names.')
param namePrefix string = 'demo2'

@description('Optional resource tags.')
param tags object = {
  project: 'demo2-sql-free'
  environment: environment
}

@description('SQL server administrator login name.')
param sqlAdminLogin string = 'sqladmin'

@secure()
@description('SQL server administrator password. Stored in Key Vault during deployment.')
param sqlAdminPassword string = ''

@description('Name of the database to create.')
param databaseName string = 'appdb'

@description('Enable the Azure SQL free offer (100k vCore-seconds and 32 GB per month).')
param useFreeLimit bool = true

@description('Public IPv4 of your PC for SQL firewall. deploy.ps1 auto-detects; set empty to skip.')
param clientIpAddress string = ''

var uniqueSuffix = uniqueString(resourceGroup().id, namePrefix, environment)

module keyVault './modules/keyvault.bicep' = {
  name: 'keyvault-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    uniqueSuffix: uniqueSuffix
    tags: tags
    sqlAdminPassword: sqlAdminPassword
  }
}

module sql './modules/sql.bicep' = {
  name: 'sql-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    environment: environment
    uniqueSuffix: uniqueSuffix
    tags: tags
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    databaseName: databaseName
    useFreeLimit: useFreeLimit
    clientIpAddress: clientIpAddress
  }
}

output keyVaultName string = keyVault.outputs.keyVaultName
output sqlAdminLogin string = sqlAdminLogin
output sqlServerName string = sql.outputs.sqlServerName
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output sqlDatabaseName string = sql.outputs.sqlDatabaseName
output connectionStringHint string = sql.outputs.connectionStringHint
output clientIpAddress string = clientIpAddress
output connectHint string = 'SSMS or Azure Data Studio → ${sql.outputs.sqlServerFqdn}, database ${databaseName}. Login: ${sqlAdminLogin}. Password: Key Vault secret sql-admin-password in ${keyVault.outputs.keyVaultName}.'
