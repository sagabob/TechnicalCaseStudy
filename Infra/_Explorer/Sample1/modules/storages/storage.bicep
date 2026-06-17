param location string = resourceGroup().location
param namePrefix string
param uniqueSuffix string
param tags object = {}

var storageAccountName = toLower(take('stg${replace(namePrefix, '-', '')}${uniqueSuffix}', 24))

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
