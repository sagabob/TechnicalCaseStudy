@description('Azure region for SQL resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, stage, prod).')
param environment string

@description('Suffix to keep SQL server names globally unique.')
param uniqueSuffix string

@description('Optional resource tags.')
param tags object = {}

@description('SQL server administrator login name.')
param sqlAdminLogin string

@secure()
@description('SQL server administrator password.')
param sqlAdminPassword string

@description('Name of the database to create.')
param databaseName string = 'appdb'

@description('Enable the Azure SQL free offer (100k vCore-seconds and 32 GB per month). Up to 10 per subscription.')
param useFreeLimit bool = true

@description('When free limits are exhausted: AutoPause pauses the DB; BillOverUsage charges standard serverless rates.')
@allowed([
  'AutoPause'
  'BillOverUsage'
])
param freeLimitExhaustionBehavior string = 'AutoPause'

@description('Public IPv4 address of your PC for SQL firewall access. Leave empty to skip.')
param clientIpAddress string = ''

var sqlServerName = take('sql-${namePrefix}-${environment}-${uniqueSuffix}', 63)

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
  }
  properties: {
    useFreeLimit: useFreeLimit
    freeLimitExhaustionBehavior: freeLimitExhaustionBehavior
    maxSizeBytes: 34359738368 // 32 GB — free offer limit
    autoPauseDelay: 60
  }
}

resource firewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource firewallAllowClient 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (!empty(clientIpAddress)) {
  parent: sqlServer
  name: 'AllowClientIp'
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}

output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
output connectionStringHint string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${databaseName};User ID=${sqlAdminLogin};Password=<from Key Vault>;Encrypt=True;'
