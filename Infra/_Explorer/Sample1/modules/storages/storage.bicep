param location string = resourceGroup().location
param namePrefix string
param uniqueSuffix string

param skuName string = 'Standard_LRS'
param kind string = 'StorageV2'
param tags object = {}

var storageAccountName = toLower(take('stg${replace(namePrefix, '-', '')}${uniqueSuffix}', 24))

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: kind
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output storageBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output storageQueueEndpoint string = storageAccount.properties.primaryEndpoints.queue
output storageTableEndpoint string = storageAccount.properties.primaryEndpoints.table
output storageFileEndpoint string = storageAccount.properties.primaryEndpoints.file


