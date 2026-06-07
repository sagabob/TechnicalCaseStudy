@description('Azure region for App Service resources.')
param location string

@description('Short prefix used in resource names.')
param namePrefix string

@description('Environment name (dev, test, prod).')
param environment string

@description('Suffix to keep web app names globally unique.')
param uniqueSuffix string

@description('Optional resource tags.')
param tags object = {}

@description('Blob service URI for the web app configuration.')
param blobEndpoint string

@description('Uploads container name for the web app configuration.')
param uploadsContainerName string

@description('Storage account name for optional role assignment scope.')
param storageAccountName string = ''

@description('Grant the web app managed identity Storage Blob Data Contributor on the storage account. Requires deploy identity to have Microsoft.Authorization/roleAssignments/write (e.g. User Access Administrator).')
param assignStorageBlobRole bool = false

@description('App Service Plan SKU name.')
param appServicePlanSku string = 'B1'

@description('App Service Plan SKU tier.')
param appServicePlanTier string = 'Basic'

var appServicePlanName = 'asp-${namePrefix}-${environment}'
var webAppName = toLower(take('app-${replace(namePrefix, '-', '')}-${environment}-${uniqueSuffix}', 60))

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: appServicePlanTier
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'BlobStorage__ServiceUri'
          value: blobEndpoint
        }
        {
          name: 'BlobStorage__UploadsContainer'
          value: uploadsContainerName
        }
      ]
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (assignStorageBlobRole) {
  name: storageAccountName
}

var storageBlobDataContributorRoleId = 'ba92f5a4-2d11-452c-a403-96ea6165af5a'

resource blobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignStorageBlobRole) {
  name: guid(storageAccount.id, webApp.id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appServicePlanName string = appServicePlan.name
output webAppName string = webApp.name
output webAppHostName string = webApp.properties.defaultHostName
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppPrincipalId string = webApp.identity.principalId
